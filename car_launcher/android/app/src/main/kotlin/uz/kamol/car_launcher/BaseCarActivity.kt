package uz.kamol.car_launcher

import android.Manifest
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channels shared by MainActivity (home screen) and DashboardActivity (split-screen copy).
 * Each activity has its own Flutter engine, so every listener is per instance.
 */
abstract class BaseCarActivity : FlutterActivity() {

    companion object {
        private const val MEDIA_CHANNEL = "car_launcher/media"
        private const val MEDIA_STATE_CHANNEL = "car_launcher/media_state"
        private const val SYSTEM_CHANNEL = "car_launcher/system"
        private const val IGNITION_CHANNEL = "car_launcher/ignition"
        private const val STATUS_CHANNEL = "car_launcher/status"
        private const val PHONE_PERMISSION_REQUEST = 42
    }

    /** True for the split-screen dashboard. */
    protected abstract val isDashboard: Boolean

    private var carSink: EventChannel.EventSink? = null
    private var mediaListener: ((Map<String, Any?>) -> Unit)? = null
    private var statusListener: ((Map<String, Any?>) -> Unit)? = null

    private val ignitionListener: (Boolean) -> Unit = { on ->
        runOnUiThread {
            applyScreenFlags(on)
            onIgnitionChanged(on)
            carSink?.success(CarState.snapshot())
        }
    }

    private val batteryListener: () -> Unit = {
        runOnUiThread { carSink?.success(CarState.snapshot()) }
    }

    protected open fun onIgnitionChanged(on: Boolean) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MediaHub.init(this)
        CarState.readBattery(this)
        CarState.addListener(ignitionListener)
        CarState.addBatteryListener(batteryListener)
        CarModeService.start(this, fromBoot = false)
        applyScreenFlags(CarState.ignitionOn)
    }

    override fun onResume() {
        super.onResume()
        MediaHub.refresh() // user may have just granted notification access
        CarState.readBattery(this)
        StatusMonitor.refresh()
        applyScreenFlags(CarState.ignitionOn)
    }

    override fun onDestroy() {
        CarState.removeListener(ignitionListener)
        CarState.removeBatteryListener(batteryListener)
        mediaListener?.let { MediaHub.removeStateListener(it) }
        mediaListener = null
        statusListener?.let { StatusMonitor.removeListener(it) }
        statusListener = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> MediaHub.play()
                "pause" -> MediaHub.pause()
                "toggle" -> MediaHub.toggle()
                "next" -> MediaHub.next()
                "previous" -> MediaHub.previous()
                "seekTo" -> MediaHub.seekTo((call.argument<Number>("positionMs") ?: 0).toLong())
                "startYandex" -> MediaHub.ensureYandexPlaying()
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(null)
        }

        EventChannel(messenger, MEDIA_STATE_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                mediaListener?.let { MediaHub.removeStateListener(it) }
                val listener: (Map<String, Any?>) -> Unit = { state -> runOnUiThread { events.success(state) } }
                mediaListener = listener
                MediaHub.addStateListener(listener)
                MediaHub.refresh()
                events.success(MediaHub.snapshot())
            }

            override fun onCancel(arguments: Any?) {
                mediaListener?.let { MediaHub.removeStateListener(it) }
                mediaListener = null
            }
        })

        // Map: {on: Boolean, level: Int (0..100, -1 unknown), charging: Boolean}
        EventChannel(messenger, IGNITION_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                carSink = events
                events.success(CarState.snapshot())
            }

            override fun onCancel(arguments: Any?) {
                carSink = null
            }
        })

        // Map: {wifiLevel: Int, cellLevel: Int (0..4, -1 none), cellType: String?}
        EventChannel(messenger, STATUS_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                statusListener?.let { StatusMonitor.removeListener(it) }
                val listener: (Map<String, Any?>) -> Unit = { state -> runOnUiThread { events.success(state) } }
                statusListener = listener
                StatusMonitor.addListener(this@BaseCarActivity, listener)
            }

            override fun onCancel(arguments: Any?) {
                statusListener?.let { StatusMonitor.removeListener(it) }
                statusListener = null
            }
        })

        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            val ctx = this@BaseCarActivity
            when (call.method) {
                "hasNotificationAccess" -> result.success(MediaHub.hasNotificationAccess())
                "hasOverlayPermission" -> result.success(SystemActions.hasOverlayPermission(ctx))
                "isDefaultLauncher" -> result.success(SystemActions.isDefaultLauncher(ctx))
                "isIgnoringBatteryOptimizations" -> result.success(SystemActions.isIgnoringBatteryOptimizations(ctx))
                "openNotificationAccessSettings" -> result.success(SystemActions.openNotificationAccessSettings(ctx))
                "openOverlaySettings" -> result.success(SystemActions.openOverlaySettings(ctx))
                "openHomeSettings" -> result.success(SystemActions.openHomeSettings(ctx))
                "openAppSettings" -> result.success(SystemActions.openAppSettings(ctx))
                "openDialer" -> result.success(SystemActions.openDialer(ctx))
                "openAlice" -> result.success(SystemActions.openAlice(ctx))
                "openAssistantSettings" -> result.success(SystemActions.openAssistantSettings(ctx))
                "launchApp" -> {
                    val pkg = call.argument<String>("package")
                    result.success(pkg != null && SystemActions.launchApp(ctx, pkg))
                }
                "isLockAdmin" -> result.success(SystemActions.isLockAdmin(ctx))
                "requestLockAdmin" -> result.success(SystemActions.requestLockAdmin(ctx))
                "hasPhonePermission" -> result.success(StatusMonitor.hasPhonePermission())
                "requestPhonePermission" -> {
                    requestPermissions(arrayOf(Manifest.permission.READ_PHONE_STATE), PHONE_PERMISSION_REQUEST)
                    result.success(null)
                }
                "isDashboard" -> result.success(isDashboard)
                "openSplit" -> {
                    val pkg = call.argument<String>("package")
                    result.success(pkg != null && SystemActions.openSplit(ctx, pkg))
                }
                "exitSplit" -> {
                    SystemActions.exitSplit(ctx)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PHONE_PERMISSION_REQUEST) StatusMonitor.refresh()
    }

    /** Ignition ON -> keep screen on. OFF -> system screen timeout turns it off. */
    private fun applyScreenFlags(ignitionOn: Boolean) {
        if (ignitionOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
