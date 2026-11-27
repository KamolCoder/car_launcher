package uz.kamol.car_launcher

import android.app.KeyguardManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val MEDIA_CHANNEL = "car_launcher/media"
        private const val MEDIA_STATE_CHANNEL = "car_launcher/media_state"
        private const val SYSTEM_CHANNEL = "car_launcher/system"
        private const val IGNITION_CHANNEL = "car_launcher/ignition"
    }

    private var ignitionSink: EventChannel.EventSink? = null

    private val ignitionListener: (Boolean) -> Unit = { on ->
        runOnUiThread {
            applyScreenFlags(on)
            if (on) dismissKeyguard()
            ignitionSink?.success(on)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Show over the lock screen and wake the screen when brought to front on ignition
        setShowWhenLocked(true)
        setTurnScreenOn(true)

        MediaHub.init(this)
        CarState.addListener(ignitionListener)
        CarModeService.start(this, fromBoot = false)
        applyScreenFlags(CarState.ignitionOn)
    }

    override fun onResume() {
        super.onResume()
        MediaHub.refresh() // user may have just granted notification access
        applyScreenFlags(CarState.ignitionOn)
    }

    override fun onDestroy() {
        CarState.removeListener(ignitionListener)
        MediaHub.onStateChanged = null
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
                MediaHub.onStateChanged = { state -> runOnUiThread { events.success(state) } }
                MediaHub.refresh()
                events.success(MediaHub.snapshot())
            }

            override fun onCancel(arguments: Any?) {
                MediaHub.onStateChanged = null
            }
        })

        EventChannel(messenger, IGNITION_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                ignitionSink = events
                events.success(CarState.ignitionOn)
            }

            override fun onCancel(arguments: Any?) {
                ignitionSink = null
            }
        })

        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            val ctx = this@MainActivity
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
                "launchApp" -> {
                    val pkg = call.argument<String>("package")
                    result.success(pkg != null && SystemActions.launchApp(ctx, pkg))
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Ignition ON -> keep screen on. OFF -> system screen timeout turns it off. */
    private fun applyScreenFlags(ignitionOn: Boolean) {
        if (ignitionOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /** Works without UI only for "Swipe"/"None" lock types. */
    private fun dismissKeyguard() {
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard.isKeyguardLocked) keyguard.requestDismissKeyguard(this, null)
    }
}
