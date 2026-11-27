package uz.kamol.car_launcher

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.telephony.SignalStrength
import android.telephony.TelephonyCallback
import android.telephony.TelephonyDisplayInfo
import android.telephony.TelephonyManager
import android.util.Log
import android.annotation.TargetApi

/**
 * Wi-Fi and cellular signal for the launcher's own status bar (system bar is hidden).
 * Levels are 0..4, -1 = not connected / no SIM.
 */
object StatusMonitor {
    private const val TAG = "StatusMonitor"

    private lateinit var appContext: Context
    private var started = false

    @Volatile
    var wifiLevel: Int = -1
        private set

    @Volatile
    var cellLevel: Int = -1
        private set

    /** "5G", "LTE+", "LTE", "3G", "2G" or null (unknown / no READ_PHONE_STATE). */
    @Volatile
    var cellType: String? = null
        private set

    private val listeners = mutableSetOf<(Map<String, Any?>) -> Unit>()
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null
    private var telephonyCallback: TelephonyCallback? = null
    private var callbackHasPhonePermission = false

    fun addListener(context: Context, listener: (Map<String, Any?>) -> Unit) {
        listeners.add(listener)
        start(context)
        listener(snapshot())
    }

    fun removeListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.remove(listener)
        if (listeners.isEmpty()) stop()
    }

    /** Re-register cellular listener if READ_PHONE_STATE was granted meanwhile. */
    fun refresh() {
        if (!started) return
        if (hasPhonePermission() != callbackHasPhonePermission) {
            unregisterCell()
            registerCell()
        }
        emit()
    }

    fun hasPhonePermission(): Boolean = ::appContext.isInitialized &&
        appContext.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED

    fun snapshot(): Map<String, Any?> = mapOf(
        "wifiLevel" to wifiLevel,
        "cellLevel" to cellLevel,
        "cellType" to cellType,
    )

    private fun start(context: Context) {
        if (started) return
        appContext = context.applicationContext
        started = true
        registerWifi()
        registerCell()
    }

    private fun stop() {
        if (!started) return
        wifiCallback?.let {
            try {
                appContext.getSystemService(ConnectivityManager::class.java).unregisterNetworkCallback(it)
            } catch (e: Exception) {
                Log.w(TAG, "unregister wifi", e)
            }
        }
        wifiCallback = null
        unregisterCell()
        started = false
    }

    private fun emit() {
        val state = snapshot()
        listeners.toList().forEach { it(state) }
    }

    // region Wi-Fi

    /** RSSI dBm -> 0..4 bars (same thresholds as Android's 5-level scale). */
    private fun wifiBars(rssi: Int): Int = when {
        rssi == NetworkCapabilities.SIGNAL_STRENGTH_UNSPECIFIED -> 0
        rssi >= -55 -> 4
        rssi >= -66 -> 3
        rssi >= -77 -> 2
        rssi >= -88 -> 1
        else -> 0
    }

    private fun registerWifi() {
        val cm = appContext.getSystemService(ConnectivityManager::class.java)
        val request = NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                // For Wi-Fi, signalStrength is RSSI in dBm
                val level = wifiBars(caps.signalStrength)
                if (level != wifiLevel) {
                    wifiLevel = level
                    emit()
                }
            }

            override fun onLost(network: Network) {
                if (wifiLevel != -1) {
                    wifiLevel = -1
                    emit()
                }
            }
        }
        try {
            // Callbacks on the main thread
            cm.registerNetworkCallback(request, callback, android.os.Handler(android.os.Looper.getMainLooper()))
            wifiCallback = callback
        } catch (e: Exception) {
            Log.w(TAG, "Cannot watch Wi-Fi", e)
        }
    }

    // endregion

    // region Cellular

    private fun telephony(): TelephonyManager? {
        if (!appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) return null
        return appContext.getSystemService(TelephonyManager::class.java)
    }

    private fun simReady(tm: TelephonyManager) = tm.simState == TelephonyManager.SIM_STATE_READY

    private fun registerCell() {
        val tm = telephony()
        if (tm == null || !simReady(tm)) {
            cellLevel = -1
            cellType = null
            return
        }
        val phone = hasPhonePermission()
        callbackHasPhonePermission = phone

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            // Android 10/11: one-shot read, refreshed on resume
            cellLevel = tm.signalStrength?.level ?: 0
            cellType = if (phone) typeLabel(networkTypeSafe(tm), TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NONE) else null
            return
        }

        val callback = if (phone) PhoneCallback() else SignalOnlyCallback()
        try {
            tm.registerTelephonyCallback(appContext.mainExecutor, callback)
            telephonyCallback = callback
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot watch cellular", e)
            if (phone) {
                callbackHasPhonePermission = false
                val fallback = SignalOnlyCallback()
                tm.registerTelephonyCallback(appContext.mainExecutor, fallback)
                telephonyCallback = fallback
            }
        }
        if (!phone) cellType = null
    }

    private fun unregisterCell() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let { telephony()?.unregisterTelephonyCallback(it) }
        }
        telephonyCallback = null
    }

    private fun onSignal(ss: SignalStrength) {
        val level = ss.level
        if (level != cellLevel) {
            cellLevel = level
            emit()
        }
    }

    private fun onDisplayInfo(info: TelephonyDisplayInfo) {
        val type = typeLabel(info.networkType, info.overrideNetworkType)
        if (type != cellType) {
            cellType = type
            emit()
        }
    }

    @TargetApi(Build.VERSION_CODES.S)
    private open inner class SignalOnlyCallback : TelephonyCallback(), TelephonyCallback.SignalStrengthsListener {
        override fun onSignalStrengthsChanged(signalStrength: SignalStrength) = onSignal(signalStrength)
    }

    /** Needs READ_PHONE_STATE for the network type (LTE / 5G). */
    @TargetApi(Build.VERSION_CODES.S)
    private inner class PhoneCallback : SignalOnlyCallback(), TelephonyCallback.DisplayInfoListener {
        override fun onDisplayInfoChanged(telephonyDisplayInfo: TelephonyDisplayInfo) =
            onDisplayInfo(telephonyDisplayInfo)
    }

    @Suppress("MissingPermission")
    private fun networkTypeSafe(tm: TelephonyManager): Int = try {
        tm.dataNetworkType
    } catch (e: SecurityException) {
        TelephonyManager.NETWORK_TYPE_UNKNOWN
    }

    private fun typeLabel(networkType: Int, override: Int): String? = when {
        override == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_NSA ||
            override == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_ADVANCED ||
            networkType == TelephonyManager.NETWORK_TYPE_NR -> "5G"
        override == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_LTE_CA -> "LTE+"
        networkType == TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
        networkType in setOf(
            TelephonyManager.NETWORK_TYPE_UMTS,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_HSPAP,
            TelephonyManager.NETWORK_TYPE_TD_SCDMA,
        ) -> "3G"
        networkType in setOf(
            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_GSM,
        ) -> "2G"
        else -> null
    }

    // endregion
}
