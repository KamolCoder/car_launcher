package uz.kamol.car_launcher

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager

/**
 * Ignition + battery state shared between CarModeService and the activities.
 * Ignition ON == tablet is charging from the car's 12V socket.
 */
object CarState {
    @Volatile
    var ignitionOn: Boolean = false
        private set

    /** Battery percent 0..100, -1 = unknown. */
    @Volatile
    var batteryLevel: Int = -1
        private set

    @Volatile
    var charging: Boolean = false
        private set

    private val listeners = mutableSetOf<(Boolean) -> Unit>()
    private val batteryListeners = mutableSetOf<() -> Unit>()

    @Synchronized
    fun addListener(listener: (Boolean) -> Unit) {
        listeners.add(listener)
    }

    @Synchronized
    fun removeListener(listener: (Boolean) -> Unit) {
        listeners.remove(listener)
    }

    @Synchronized
    fun addBatteryListener(listener: () -> Unit) {
        batteryListeners.add(listener)
    }

    @Synchronized
    fun removeBatteryListener(listener: () -> Unit) {
        batteryListeners.remove(listener)
    }

    /** Returns true if the state actually changed. */
    @Synchronized
    fun update(on: Boolean): Boolean {
        if (ignitionOn == on) return false
        ignitionOn = on
        listeners.toList().forEach { it(on) }
        return true
    }

    /** Parses ACTION_BATTERY_CHANGED: percent = level * 100 / scale. */
    @Synchronized
    fun updateBattery(intent: Intent?) {
        intent ?: return
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val percent = if (level >= 0 && scale > 0) level * 100 / scale else -1
        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        if (percent == batteryLevel && isCharging == charging) return
        batteryLevel = percent
        charging = isCharging
        batteryListeners.toList().forEach { it() }
    }

    /** ACTION_BATTERY_CHANGED is sticky: a null receiver returns the last value immediately. */
    fun readBattery(context: Context) {
        updateBattery(context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)))
    }

    fun snapshot(): Map<String, Any?> = mapOf(
        "on" to ignitionOn,
        "level" to batteryLevel,
        "charging" to charging,
    )
}
