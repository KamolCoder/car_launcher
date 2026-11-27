package uz.kamol.car_launcher

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * Same Flutter UI as MainActivity, but a normal resizeable task (no HOME category),
 * so it can sit in split screen next to Yandex Navigator.
 */
class DashboardActivity : BaseCarActivity() {

    companion object {
        private const val EXTRA_ADJACENT_PACKAGE = "adjacent_package"

        /** Delay so this activity is resumed full-screen before the adjacent launch. */
        private const val ADJACENT_DELAY_MS = 400L

        /** True while the dashboard is visible in multi-window (split) mode. */
        @Volatile
        var inSplit: Boolean = false
            private set

        fun start(context: Context, adjacentPackage: String) {
            val intent = Intent(context, DashboardActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(EXTRA_ADJACENT_PACKAGE, adjacentPackage)
            context.startActivity(intent)
        }
    }

    override val isDashboard = true

    private val handler = Handler(Looper.getMainLooper())
    private var pendingPackage: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingPackage = intent?.getStringExtra(EXTRA_ADJACENT_PACKAGE)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingPackage = intent.getStringExtra(EXTRA_ADJACENT_PACKAGE)
    }

    override fun onResume() {
        super.onResume()
        inSplit = isInMultiWindowMode
        val pkg = pendingPackage ?: return
        pendingPackage = null
        handler.postDelayed({ SystemActions.launchAdjacent(this, pkg) }, ADJACENT_DELAY_MS)
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        inSplit = isInMultiWindowMode
    }

    override fun onDestroy() {
        inSplit = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
