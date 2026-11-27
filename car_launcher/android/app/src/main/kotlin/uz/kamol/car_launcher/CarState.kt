package uz.kamol.car_launcher

/**
 * Ignition state shared between CarModeService and MainActivity.
 * Ignition ON == tablet is charging from the car's 12V socket.
 */
object CarState {
    @Volatile
    var ignitionOn: Boolean = false
        private set

    private val listeners = mutableSetOf<(Boolean) -> Unit>()

    @Synchronized
    fun addListener(listener: (Boolean) -> Unit) {
        listeners.add(listener)
    }

    @Synchronized
    fun removeListener(listener: (Boolean) -> Unit) {
        listeners.remove(listener)
    }

    /** Returns true if the state actually changed. */
    @Synchronized
    fun update(on: Boolean): Boolean {
        if (ignitionOn == on) return false
        ignitionOn = on
        listeners.toList().forEach { it(on) }
        return true
    }
}
