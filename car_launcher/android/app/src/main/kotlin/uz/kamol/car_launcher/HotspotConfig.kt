package uz.kamol.car_launcher

import android.content.Context
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.util.Log

/**
 * iPhone hotspot: saved name/password + WifiNetworkSuggestion so Android auto-joins it
 * as soon as the iPhone starts broadcasting. Android asks the user once to allow suggestions.
 */
object HotspotConfig {
    private const val TAG = "HotspotConfig"
    private const val PREFS = "hotspot"
    private const val KEY_SSID = "ssid"
    private const val KEY_PASSWORD = "password"

    /** WPA2 passphrase is 8..63 chars; empty = open network. */
    private const val MIN_PASSWORD = 8

    fun ssid(context: Context): String? =
        prefs(context).getString(KEY_SSID, null)?.takeIf { it.isNotBlank() }

    /**
     * Saves and (re)registers the suggestion.
     * Returns null on success, else an error text for the UI.
     */
    fun save(context: Context, ssid: String, password: String): String? {
        val name = ssid.trim()
        if (name.isEmpty()) return clear(context)
        if (password.isNotEmpty() && password.length < MIN_PASSWORD) return "Пароль минимум 8 символов"

        val wifi = context.getSystemService(WifiManager::class.java)
        removeSuggestion(context, wifi)

        val builder = WifiNetworkSuggestion.Builder()
            .setSsid(name)
            .setIsAppInteractionRequired(false)
            .setPriority(Int.MAX_VALUE)
        // iPhone uses WPA2/WPA3 transition mode -> WPA2 passphrase matches it
        if (password.isNotEmpty()) builder.setWpa2Passphrase(password)
        val suggestion = builder.build()

        val status = try {
            wifi.addNetworkSuggestions(listOf(suggestion))
        } catch (e: Exception) {
            Log.w(TAG, "addNetworkSuggestions failed", e)
            return "Android не принял сеть: ${e.message}"
        }
        if (status != WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS) {
            return "Android не принял сеть (код $status)"
        }
        prefs(context).edit().putString(KEY_SSID, name).putString(KEY_PASSWORD, password).apply()
        return null
    }

    private fun clear(context: Context): String? {
        removeSuggestion(context, context.getSystemService(WifiManager::class.java))
        prefs(context).edit().clear().apply()
        return null
    }

    private fun removeSuggestion(context: Context, wifi: WifiManager) {
        val oldSsid = ssid(context) ?: return
        val old = WifiNetworkSuggestion.Builder().setSsid(oldSsid).apply {
            val pass = prefs(context).getString(KEY_PASSWORD, "").orEmpty()
            if (pass.isNotEmpty()) setWpa2Passphrase(pass)
        }.build()
        try {
            wifi.removeNetworkSuggestions(listOf(old))
        } catch (e: Exception) {
            Log.w(TAG, "removeNetworkSuggestions failed", e)
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
