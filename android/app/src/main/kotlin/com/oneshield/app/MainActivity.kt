package com.oneshield.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.oneshield.app/autofill"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncCredentials" -> {
                    try {
                        val credentials = call.argument<String>("credentials") ?: "[]"
                        Log.d("OneShieldAutofill", "syncCredentials called, entries synced")
                        saveCredentials(credentials)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneShieldAutofill", "syncCredentials error", e)
                        result.error("SYNC_ERROR", e.message, null)
                    }
                }

                "clearCredentials" -> {
                    try {
                        Log.d("OneShieldAutofill", "clearCredentials called")
                        clearCredentials()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneShieldAutofill", "clearCredentials error", e)
                        result.error("CLEAR_ERROR", e.message, null)
                    }
                }

                "isAutofillEnabled" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val afm = getSystemService(AutofillManager::class.java)
                        val supported = afm?.isAutofillSupported == true
                        val hasService = afm?.hasEnabledAutofillServices() == true
                        Log.d("OneShieldAutofill", "isAutofillSupported=$supported, hasEnabledServices=$hasService")
                        result.success(hasService)
                    } else {
                        result.success(false)
                    }
                }

                "openAutofillSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneShieldAutofill", "openAutofillSettings error", e)
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                "openSystemAutofillSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneShieldAutofill", "openSystemAutofillSettings error", e)
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                "debugAutofill" -> {
                    try {
                        val info = mutableMapOf<String, Any>()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val afm = getSystemService(AutofillManager::class.java)
                            info["autofillSupported"] = afm?.isAutofillSupported == true
                            info["hasEnabledServices"] = afm?.hasEnabledAutofillServices() == true
                            info["isEnabled"] = afm?.isEnabled == true
                        } else {
                            info["autofillSupported"] = false
                            info["hasEnabledServices"] = false
                            info["isEnabled"] = false
                        }

                        // Check stored credential count
                        try {
                            val masterKey = MasterKey.Builder(this)
                                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                                .build()
                            val prefs = EncryptedSharedPreferences.create(
                                this,
                                OneShieldAutofillService.PREFS_NAME,
                                masterKey,
                                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                            )
                            val json = prefs.getString(OneShieldAutofillService.KEY_CREDENTIALS, null)
                            info["storedCredentialsLength"] = json?.length ?: 0
                            if (json != null) {
                                val arr = org.json.JSONArray(json)
                                info["storedCredentialsCount"] = arr.length()
                            } else {
                                info["storedCredentialsCount"] = 0
                            }
                        } catch (e: Exception) {
                            info["storageError"] = e.message ?: "unknown"
                        }

                        info["androidVersion"] = Build.VERSION.SDK_INT
                        info["packageName"] = packageName

                        // Don't log debug info as it may contain credential counts
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("DEBUG_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun saveCredentials(credentialsJson: String) {
        val masterKey = MasterKey.Builder(this)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        val prefs = EncryptedSharedPreferences.create(
            this,
            OneShieldAutofillService.PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )

        prefs.edit()
            .putString(OneShieldAutofillService.KEY_CREDENTIALS, credentialsJson)
            .apply()
    }

    private fun clearCredentials() {
        val masterKey = MasterKey.Builder(this)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        val prefs = EncryptedSharedPreferences.create(
            this,
            OneShieldAutofillService.PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )

        prefs.edit().clear().apply()
    }
}
