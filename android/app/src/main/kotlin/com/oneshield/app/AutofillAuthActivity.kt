package com.oneshield.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import org.json.JSONObject

/**
 * Authentication activity for autofill.
 * Shows device lock screen (PIN/pattern/biometric) before filling credentials.
 */
@RequiresApi(Build.VERSION_CODES.O)
class AutofillAuthActivity : Activity() {

    companion object {
        const val TAG = "OneShieldAutofillAuth"
        const val EXTRA_CREDENTIAL_JSON = "credential_json"
        const val EXTRA_USERNAME_IDS = "username_ids"
        const val EXTRA_PASSWORD_IDS = "password_ids"
        private const val REQUEST_CODE_CONFIRM = 1001
    }

    private var credentialJson: String? = null
    private var usernameIds: Array<AutofillId>? = null
    private var passwordIds: Array<AutofillId>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        credentialJson = intent.getStringExtra(EXTRA_CREDENTIAL_JSON)
        usernameIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayExtra(EXTRA_USERNAME_IDS, AutofillId::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayExtra(EXTRA_USERNAME_IDS)?.map { it as AutofillId }?.toTypedArray()
        }
        passwordIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayExtra(EXTRA_PASSWORD_IDS, AutofillId::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayExtra(EXTRA_PASSWORD_IDS)?.map { it as AutofillId }?.toTypedArray()
        }

        Log.d(TAG, "Auth activity created")

        // Launch device authentication (PIN/pattern/biometric)
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (keyguardManager.isDeviceSecure) {
            val authIntent = keyguardManager.createConfirmDeviceCredentialIntent(
                "OneShield Autofill",
                "Verify your identity to fill credentials"
            )
            if (authIntent != null) {
                startActivityForResult(authIntent, REQUEST_CODE_CONFIRM)
            } else {
                // No lock screen set, fill directly
                fillAndFinish()
            }
        } else {
            // Device not secured, fill directly
            fillAndFinish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_CONFIRM) {
            if (resultCode == RESULT_OK) {
                Log.d(TAG, "Authentication successful")
                fillAndFinish()
            } else {
                Log.d(TAG, "Authentication cancelled/failed")
                setResult(RESULT_CANCELED)
                finish()
            }
        }
    }

    private fun fillAndFinish() {
        try {
            val cred = JSONObject(credentialJson ?: "{}")
            val username = cred.optString("username", "")
            val password = cred.optString("password", "")
            val title = cred.optString("title", "OneShield")

            val datasetBuilder = Dataset.Builder()
            var hasFields = false

            // Fill username fields
            usernameIds?.forEach { id ->
                if (username.isNotEmpty()) {
                    val presentation = RemoteViews(packageName, R.layout.autofill_item)
                    presentation.setTextViewText(R.id.autofill_title, title)
                    presentation.setTextViewText(R.id.autofill_subtitle, username)
                    datasetBuilder.setValue(id, AutofillValue.forText(username), presentation)
                    hasFields = true
                }
            }

            // Fill password fields
            passwordIds?.forEach { id ->
                if (password.isNotEmpty()) {
                    val presentation = RemoteViews(packageName, R.layout.autofill_item)
                    presentation.setTextViewText(R.id.autofill_title, title)
                    presentation.setTextViewText(R.id.autofill_subtitle, "••••••••")
                    datasetBuilder.setValue(id, AutofillValue.forText(password), presentation)
                    hasFields = true
                }
            }

            if (hasFields) {
                val replyIntent = Intent()
                replyIntent.putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, datasetBuilder.build())
                setResult(RESULT_OK, replyIntent)
                Log.d(TAG, "Autofill dataset set as result")
            } else {
                setResult(RESULT_CANCELED)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error building autofill dataset", e)
            setResult(RESULT_CANCELED)
        }
        finish()
    }
}
