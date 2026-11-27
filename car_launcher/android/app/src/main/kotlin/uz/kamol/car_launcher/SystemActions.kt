package uz.kamol.car_launcher

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

object SystemActions {
    private const val TAG = "SystemActions"

    /** Requires "Display over other apps" when called from background (Android 10+). */
    fun bringLauncherToFront(context: Context) {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        safeStart(context, intent)
    }

    fun launchApp(context: Context, packageName: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return safeStart(context, intent)
    }

    /**
     * Split screen: [packageName] on one side, DashboardActivity on the other.
     * The home task can't be split, so the dashboard (a normal task) is started first
     * and it launches the app with FLAG_ACTIVITY_LAUNCH_ADJACENT once resumed.
     */
    fun openSplit(activity: Activity, packageName: String): Boolean {
        if (activity.packageManager.getLaunchIntentForPackage(packageName) == null) return false
        return if (activity is DashboardActivity) {
            launchAdjacent(activity, packageName)
        } else {
            try {
                DashboardActivity.start(activity, packageName)
                true
            } catch (e: Exception) {
                Log.w(TAG, "Cannot start dashboard", e)
                false
            }
        }
    }

    /** Opens the app next to [activity]; existing task (e.g. active route) is reused. */
    fun launchAdjacent(activity: Activity, packageName: String): Boolean {
        val intent = activity.packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT)
        return safeStart(activity, intent)
    }

    /** Back to the full-screen home launcher; the other app stays in recents. */
    fun exitSplit(activity: Activity) {
        bringLauncherToFront(activity)
        if (activity is DashboardActivity) activity.finishAndRemoveTask()
    }

    // region Lock (device admin)

    private fun adminComponent(context: Context) = ComponentName(context, LockAdminReceiver::class.java)

    fun isLockAdmin(context: Context): Boolean {
        val dpm = context.getSystemService(DevicePolicyManager::class.java)
        return dpm.isAdminActive(adminComponent(context))
    }

    /** System dialog "Activate device admin app". */
    fun requestLockAdmin(context: Context): Boolean = safeStart(
        context,
        Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent(context))
            .putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Нужно, чтобы планшет блокировался сразу после выключения зажигания",
            ),
    )

    /** Screen off + lock right now. Returns false if device admin is not active. */
    fun lockNow(context: Context): Boolean {
        if (!isLockAdmin(context)) return false
        return try {
            context.getSystemService(DevicePolicyManager::class.java).lockNow()
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "lockNow failed", e)
            false
        }
    }

    // endregion

    // region Alice

    /** Yandex apps that contain Alice, in priority order. */
    private val ALICE_PACKAGES = listOf(
        "com.yandex.searchapp", // "Яндекс с Алисой"
        "ru.yandex.searchplugin", // older "Яндекс"
    )

    /**
     * Opens Alice listening.
     * 1. Default assistant (Yandex set as digital assistant) -> ACTION_VOICE_COMMAND, opens over the current app.
     * 2. Voice command activity inside a Yandex app.
     * 3. Just launch the Yandex app.
     */
    fun openAlice(context: Context): Boolean {
        val pm = context.packageManager
        val assistant = Intent(Intent.ACTION_VOICE_COMMAND)
        val resolved = pm.resolveActivity(assistant, 0)?.activityInfo?.packageName
        if (resolved != null && resolved in ALICE_PACKAGES && safeStart(context, assistant)) return true

        for (pkg in ALICE_PACKAGES) {
            val voice = Intent(Intent.ACTION_VOICE_COMMAND).setPackage(pkg)
            if (pm.resolveActivity(voice, 0) != null && safeStart(context, voice)) return true
        }
        for (pkg in ALICE_PACKAGES) {
            if (launchApp(context, pkg)) return true
        }
        return false
    }

    /** "Default apps" screen: Digital assistant app -> Яндекс. */
    fun openAssistantSettings(context: Context): Boolean =
        safeStart(context, Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)) ||
            safeStart(context, Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))

    // endregion

    fun openDialer(context: Context): Boolean =
        safeStart(context, Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))

    fun hasOverlayPermission(context: Context): Boolean = Settings.canDrawOverlays(context)

    fun isDefaultLauncher(context: Context): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val info = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return info?.activityInfo?.packageName == context.packageName
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun openNotificationAccessSettings(context: Context) =
        safeStart(context, Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))

    fun openOverlaySettings(context: Context) = safeStart(
        context,
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}")),
    )

    fun openHomeSettings(context: Context) = safeStart(context, Intent(Settings.ACTION_HOME_SETTINGS))

    fun openAppSettings(context: Context) = safeStart(
        context,
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
    )

    private fun safeStart(context: Context, intent: Intent): Boolean = try {
        if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        true
    } catch (e: Exception) {
        Log.w(TAG, "Cannot start $intent", e)
        false
    }
}
