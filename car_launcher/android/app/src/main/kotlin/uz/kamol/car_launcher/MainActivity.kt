package uz.kamol.car_launcher

import android.app.KeyguardManager
import android.os.Bundle

/** Home screen (HOME category). Android never puts the home task into split screen. */
class MainActivity : BaseCarActivity() {

    override val isDashboard = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Show over the lock screen and wake the screen when brought to front on ignition
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    }

    override fun onIgnitionChanged(on: Boolean) {
        if (on) dismissKeyguard()
    }

    /** Works without UI only for "Swipe"/"None" lock types. */
    private fun dismissKeyguard() {
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard.isKeyguardLocked) keyguard.requestDismissKeyguard(this, null)
    }
}
