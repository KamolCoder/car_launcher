package uz.kamol.car_launcher

import android.service.notification.NotificationListenerService

/**
 * Empty listener. Its only purpose: once the user grants "Notification access",
 * the app is allowed to call MediaSessionManager.getActiveSessions().
 */
class MediaListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        MediaHub.init(this)
        MediaHub.refresh()
    }
}
