package uz.kamol.car_launcher

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import java.io.ByteArrayOutputStream

/**
 * Tracks the active media session (Yandex Music preferred) and sends commands to it.
 */
object MediaHub {
    private const val TAG = "MediaHub"
    const val YANDEX_MUSIC = "ru.yandex.music"
    private const val ART_MAX_SIZE = 600
    private const val YANDEX_START_TIMEOUT_MS = 6_000L

    private lateinit var appContext: Context
    private lateinit var sessionManager: MediaSessionManager
    private lateinit var audioManager: AudioManager
    private lateinit var listenerComponent: ComponentName

    private val mainHandler = Handler(Looper.getMainLooper())
    private var initialized = false
    private var sessionsListenerRegistered = false
    private var controller: MediaController? = null
    private var lastArtKey: String? = null
    private var pendingYandexPlay = false

    /** Called on the main thread with a state map for Flutter (one per Flutter engine). */
    private val stateListeners = mutableSetOf<(Map<String, Any?>) -> Unit>()

    fun addStateListener(listener: (Map<String, Any?>) -> Unit) {
        stateListeners.add(listener)
    }

    fun removeStateListener(listener: (Map<String, Any?>) -> Unit) {
        stateListeners.remove(listener)
    }

    fun init(context: Context) {
        if (initialized) return
        appContext = context.applicationContext
        sessionManager = appContext.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        listenerComponent = ComponentName(appContext, MediaListenerService::class.java)
        initialized = true
        refresh()
    }

    fun hasNotificationAccess(): Boolean {
        if (!initialized) return false
        val flat = Settings.Secure.getString(appContext.contentResolver, "enabled_notification_listeners")
            ?: return false
        return flat.split(":").any {
            ComponentName.unflattenFromString(it)?.packageName == appContext.packageName
        }
    }

    fun refresh() {
        if (!initialized) return
        if (!hasNotificationAccess()) {
            attach(null)
            return
        }
        try {
            if (!sessionsListenerRegistered) {
                sessionManager.addOnActiveSessionsChangedListener(sessionsListener, listenerComponent, mainHandler)
                sessionsListenerRegistered = true
            }
            attach(pickController(activeSessions()))
        } catch (e: SecurityException) {
            Log.w(TAG, "No access to media sessions", e)
            attach(null)
        }
    }

    // region Commands

    fun play() {
        controller?.transportControls?.play() ?: dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY)
    }

    fun pause() {
        val c = controller ?: return
        if (c.playbackState?.state == PlaybackState.STATE_PLAYING) c.transportControls.pause()
    }

    fun toggle() {
        val c = controller
        when {
            c == null -> ensureYandexPlaying()
            c.playbackState?.state == PlaybackState.STATE_PLAYING -> c.transportControls.pause()
            else -> c.transportControls.play()
        }
    }

    fun next() {
        controller?.transportControls?.skipToNext() ?: dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_NEXT)
    }

    fun previous() {
        controller?.transportControls?.skipToPrevious() ?: dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
    }

    fun seekTo(positionMs: Long) {
        controller?.transportControls?.seekTo(positionMs)
    }

    /**
     * Ignition ON: make Yandex Music play.
     * If its session exists -> play. Otherwise launch the app and play once the session appears.
     */
    fun ensureYandexPlaying() {
        if (!initialized) return
        refresh()

        val yandex = activeSessions().firstOrNull { it.packageName == YANDEX_MUSIC }
        if (yandex != null) {
            if (yandex.playbackState?.state != PlaybackState.STATE_PLAYING) yandex.transportControls.play()
            return
        }

        val launch = appContext.packageManager.getLaunchIntentForPackage(YANDEX_MUSIC) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        pendingYandexPlay = true
        try {
            appContext.startActivity(launch)
        } catch (e: Exception) {
            Log.w(TAG, "Cannot start Yandex Music", e)
            pendingYandexPlay = false
            return
        }

        // Fallback: session did not appear (e.g. no notification access) -> media key + back to launcher
        mainHandler.postDelayed({
            if (pendingYandexPlay) {
                pendingYandexPlay = false
                dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY)
                SystemActions.bringLauncherToFront(appContext)
            }
        }, YANDEX_START_TIMEOUT_MS)
    }

    // endregion

    /** Full state for a new Flutter listener (always includes album art). */
    fun snapshot(): Map<String, Any?> = buildState(forceArt = true)

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { list ->
        val sessions = list ?: emptyList()
        if (pendingYandexPlay) {
            sessions.firstOrNull { it.packageName == YANDEX_MUSIC }?.let { yandex ->
                pendingYandexPlay = false
                yandex.transportControls.play()
                mainHandler.postDelayed({ SystemActions.bringLauncherToFront(appContext) }, 1_500)
            }
        }
        attach(pickController(sessions))
    }

    private val controllerCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) = emit()
        override fun onMetadataChanged(metadata: MediaMetadata?) = emit()
        override fun onSessionDestroyed() = refresh()
    }

    private fun activeSessions(): List<MediaController> = try {
        sessionManager.getActiveSessions(listenerComponent)
    } catch (e: SecurityException) {
        emptyList()
    }

    /** Priority: playing session -> Yandex Music -> any. */
    private fun pickController(sessions: List<MediaController>): MediaController? =
        sessions.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: sessions.firstOrNull { it.packageName == YANDEX_MUSIC }
            ?: sessions.firstOrNull()

    private fun attach(newController: MediaController?) {
        if (controller?.sessionToken == newController?.sessionToken) {
            emit()
            return
        }
        controller?.unregisterCallback(controllerCallback)
        controller = newController
        lastArtKey = null
        newController?.registerCallback(controllerCallback, mainHandler)
        emit()
    }

    private fun emit() {
        if (stateListeners.isEmpty()) return
        val state = buildState(forceArt = false)
        stateListeners.toList().forEach { it(state) }
    }

    private fun buildState(forceArt: Boolean): Map<String, Any?> {
        val c = controller
        val meta = c?.metadata
        val state = c?.playbackState

        val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE)
        val artist = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
        val album = meta?.getString(MediaMetadata.METADATA_KEY_ALBUM)
        val duration = meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L

        val artKey = "${c?.packageName}|$title|$artist|$album"
        val artChanged = forceArt || artKey != lastArtKey
        val art = if (artChanged) {
            lastArtKey = artKey
            meta?.let { encodeArt(it) }
        } else {
            null
        }

        return mapOf(
            "hasAccess" to hasNotificationAccess(),
            "package" to c?.packageName,
            "title" to title,
            "artist" to artist,
            "durationMs" to duration,
            "positionMs" to (state?.let { currentPosition(it, duration) } ?: 0L),
            "playing" to (state?.state == PlaybackState.STATE_PLAYING),
            "speed" to (state?.playbackSpeed ?: 1f).toDouble(),
            "artChanged" to artChanged,
            "art" to art,
        )
    }

    /** position = lastPosition + (now - lastUpdate) * speed */
    private fun currentPosition(state: PlaybackState, duration: Long): Long {
        if (state.state != PlaybackState.STATE_PLAYING) return state.position
        val elapsed = SystemClock.elapsedRealtime() - state.lastPositionUpdateTime
        val position = state.position + (elapsed * state.playbackSpeed).toLong()
        return if (duration > 0) position.coerceIn(0L, duration) else position
    }

    private fun encodeArt(meta: MediaMetadata): ByteArray? {
        val bitmap = meta.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: meta.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: meta.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
            ?: return null
        return try {
            val scale = minOf(1f, ART_MAX_SIZE.toFloat() / maxOf(bitmap.width, bitmap.height))
            val scaled = if (scale < 1f) {
                Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
            } else {
                bitmap
            }
            ByteArrayOutputStream().use { out ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
                out.toByteArray()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Cannot encode album art", e)
            null
        }
    }

    private fun dispatchMediaKey(keyCode: Int) {
        if (!initialized) return
        audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
    }
}
