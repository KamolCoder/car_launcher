package uz.kamol.car_launcher

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log

/**
 * Foreground service: charger connected = ignition ON, charger gone = ignition OFF.
 * ACTION_POWER_CONNECTED can't be received from the manifest since Android 8,
 * so we register the receiver dynamically here.
 */
class CarModeService : Service() {

    companion object {
        private const val TAG = "CarModeService"
        private const val CHANNEL_ID = "car_mode"
        private const val NOTIFICATION_ID = 1001
        private const val EXTRA_FROM_BOOT = "from_boot"

        /** Power must be stable this long before we treat it as ignition ON. */
        private const val ON_DEBOUNCE_MS = 1_500L

        /** Cranking the starter drops power for a moment -> ignore short drops. */
        private const val OFF_DEBOUNCE_MS = 8_000L

        /** Time for players to pause and the launcher to come to front before locking. */
        private const val LOCK_DELAY_MS = 1_500L

        fun start(context: Context, fromBoot: Boolean) {
            val intent = Intent(context, CarModeService::class.java).putExtra(EXTRA_FROM_BOOT, fromBoot)
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Cannot start service", e)
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var receiverRegistered = false

    private var screenLock: PowerManager.WakeLock? = null

    private val lockRunnable = Runnable {
        if (CarState.ignitionOn) return@Runnable // power came back meanwhile
        releaseScreen()
        SystemActions.lockNow(this) // no device admin -> system screen timeout turns it off
    }

    private val ignitionOnRunnable = Runnable { onIgnition(true) }
    private val ignitionOffRunnable = Runnable { onIgnition(false) }

    private val powerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_POWER_CONNECTED -> {
                    handler.removeCallbacks(ignitionOffRunnable)
                    handler.removeCallbacks(ignitionOnRunnable)
                    handler.postDelayed(ignitionOnRunnable, ON_DEBOUNCE_MS)
                }
                Intent.ACTION_POWER_DISCONNECTED -> {
                    handler.removeCallbacks(ignitionOnRunnable)
                    handler.removeCallbacks(ignitionOffRunnable)
                    handler.postDelayed(ignitionOffRunnable, OFF_DEBOUNCE_MS)
                }
                Intent.ACTION_BATTERY_CHANGED -> CarState.updateBattery(intent)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        MediaHub.init(this)
        registerPowerReceiver()
        // Silent sync: no autoplay just because the app was (re)started
        CarState.update(isCharging())
        CarState.readBattery(this)
        if (CarState.ignitionOn) holdScreen()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val fromBoot = intent?.getBooleanExtra(EXTRA_FROM_BOOT, false) ?: false
        // Tablet booted already on car power -> behave as ignition ON
        if (fromBoot && CarState.ignitionOn) runIgnitionOnActions()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releaseScreen()
        if (receiverRegistered) unregisterReceiver(powerReceiver)
        receiverRegistered = false
        super.onDestroy()
    }

    private fun onIgnition(on: Boolean) {
        if (!CarState.update(on)) return
        if (on) runIgnitionOnActions() else runIgnitionOffActions()
    }

    private fun runIgnitionOnActions() {
        handler.removeCallbacks(lockRunnable)
        holdScreen() // wakes the screen and keeps it on whatever app is in front
        MediaHub.releaseAudioFocus()
        SystemActions.bringLauncherToFront(this)
        handler.postDelayed({ MediaHub.ensureYandexPlaying() }, 1_000)
    }

    /** Stop all audio -> launcher to front (other apps go to background) -> lock. */
    private fun runIgnitionOffActions() {
        MediaHub.pauseAll()
        SystemActions.bringLauncherToFront(this)
        handler.removeCallbacks(lockRunnable)
        handler.postDelayed(lockRunnable, LOCK_DELAY_MS)
    }

    /** Screen stays on while ignition is ON, even with Navigator full screen. */
    @Suppress("DEPRECATION") // SCREEN_BRIGHT_WAKE_LOCK: still the only way for a non-activity
    @SuppressLint("WakelockTimeout") // held for the whole trip, released on ignition OFF
    private fun holdScreen() {
        if (screenLock?.isHeld == true) return
        val pm = getSystemService(PowerManager::class.java)
        screenLock = pm.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "car_launcher:screen",
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseScreen() {
        screenLock?.let { if (it.isHeld) it.release() }
        screenLock = null
    }

    private fun registerPowerReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(powerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(powerReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun isCharging(): Boolean {
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        return (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Режим авто", NotificationManager.IMPORTANCE_MIN),
        )
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Car Launcher")
            .setContentText("Режим авто активен")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setContentIntent(openApp)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
