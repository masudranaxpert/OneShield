package com.oneshield.app

import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.*
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONObject
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

@RequiresApi(Build.VERSION_CODES.O)
class OneShieldAutofillService : AutofillService() {

    companion object {
        const val TAG = "OneShieldAutofill"
        const val PREFS_NAME = "oneshield_autofill_prefs"
        const val KEY_CREDENTIALS = "autofill_credentials"
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        Log.d(TAG, "=== onFillRequest called ===")
        try {
            val structure = request.fillContexts.lastOrNull()?.structure
            if (structure == null) {
                Log.d(TAG, "No structure found, returning null")
                callback.onSuccess(null)
                return
            }

            // Parse form fields from the screen
            val fields = mutableListOf<ParsedField>()
            for (i in 0 until structure.windowNodeCount) {
                val windowNode = structure.getWindowNodeAt(i)
                parseNode(windowNode.rootViewNode, fields)
            }

            val usernameFields = fields.filter { it.type == FieldType.USERNAME }
            val passwordFields = fields.filter { it.type == FieldType.PASSWORD }

            Log.d(TAG, "Found ${usernameFields.size} username fields, ${passwordFields.size} password fields")

            if (usernameFields.isEmpty() && passwordFields.isEmpty()) {
                Log.d(TAG, "No autofillable fields found, returning null")
                callback.onSuccess(null)
                return
            }

            // Load stored credentials
            val credentials = loadCredentials()
            Log.d(TAG, "Loaded ${credentials.size} credentials from storage")

            if (credentials.isEmpty()) {
                Log.d(TAG, "No credentials stored, returning null")
                callback.onSuccess(null)
                return
            }

            // Get web domain from the structure
            var webDomain: String? = null
            for (i in 0 until structure.windowNodeCount) {
                val domain = findWebDomain(structure.getWindowNodeAt(i).rootViewNode)
                if (domain != null) {
                    webDomain = domain
                    break
                }
            }

            // Also get the app package name
            val appPackage = structure.activityComponent?.packageName

            Log.d(TAG, "Web domain: $webDomain, App package: $appPackage")

            // Match credentials by URL/domain
            val matching = if (webDomain != null || appPackage != null) {
                credentials.filter { cred ->
                    val url = cred.optString("url", "").lowercase()
                    val credDomain = extractDomain(url)
                    val matched = if (webDomain != null) {
                        val wd = webDomain.lowercase()
                        url.contains(wd) ||
                        wd.contains(credDomain) ||
                        credDomain.contains(wd)
                    } else if (appPackage != null) {
                        url.contains(appPackage.lowercase())
                    } else {
                        false
                    }
                    matched
                }
            } else {
                // No domain info available, show ALL credentials so user can pick
                Log.d(TAG, "No domain info, showing all credentials")
                credentials
            }

            Log.d(TAG, "Matching credentials: ${matching.size}")

            if (matching.isEmpty()) {
                Log.d(TAG, "No matching credentials, returning null")
                callback.onSuccess(null)
                return
            }

            // Build autofill response with matching credentials
            val responseBuilder = FillResponse.Builder()
            var hasDatasets = false

            for (cred in matching) {
                val title = cred.optString("title", "Unknown")
                val username = cred.optString("username", "")
                val password = cred.optString("password", "")

                if (username.isEmpty() && password.isEmpty()) continue

                // Create auth intent for this credential
                val authIntent = Intent(this, AutofillAuthActivity::class.java)
                authIntent.putExtra(AutofillAuthActivity.EXTRA_CREDENTIAL_JSON, cred.toString())
                authIntent.putExtra(
                    AutofillAuthActivity.EXTRA_USERNAME_IDS,
                    usernameFields.map { it.autofillId }.toTypedArray()
                )
                authIntent.putExtra(
                    AutofillAuthActivity.EXTRA_PASSWORD_IDS,
                    passwordFields.map { it.autofillId }.toTypedArray()
                )

                val pendingIntent = android.app.PendingIntent.getActivity(
                    this,
                    cred.hashCode(),
                    authIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )

                val datasetBuilder = Dataset.Builder()
                var hasFields = false

                // Set presentation for username fields (shows locked item)
                for (field in usernameFields) {
                    if (username.isNotEmpty()) {
                        val presentation = createPresentation(title, username)
                        datasetBuilder.setValue(
                            field.autofillId,
                            null, // Don't set value directly - auth will fill it
                            presentation
                        )
                        hasFields = true
                    }
                }

                // Set presentation for password fields
                for (field in passwordFields) {
                    if (password.isNotEmpty()) {
                        val presentation = createPresentation(title, "••••••••")
                        datasetBuilder.setValue(
                            field.autofillId,
                            null, // Don't set value directly - auth will fill it
                            presentation
                        )
                        hasFields = true
                    }
                }

                if (hasFields) {
                    datasetBuilder.setAuthentication(pendingIntent.intentSender)
                    responseBuilder.addDataset(datasetBuilder.build())
                    hasDatasets = true
                    Log.d(TAG, "Added authenticated dataset for '$title'")
                }
            }

            if (hasDatasets) {
                Log.d(TAG, "Returning fill response with datasets")
                callback.onSuccess(responseBuilder.build())
            } else {
                Log.d(TAG, "No datasets built, returning null")
                callback.onSuccess(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onFillRequest", e)
            callback.onSuccess(null)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // Currently not implementing auto-save from browsers
        callback.onSuccess()
    }

    private fun createPresentation(title: String, subtitle: String): RemoteViews {
        val presentation = RemoteViews(packageName, R.layout.autofill_item)
        presentation.setTextViewText(R.id.autofill_title, title)
        presentation.setTextViewText(R.id.autofill_subtitle, subtitle)
        return presentation
    }

    private fun loadCredentials(): List<JSONObject> {
        return try {
            val masterKey = MasterKey.Builder(this)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val prefs = EncryptedSharedPreferences.create(
                this,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            val json = prefs.getString(KEY_CREDENTIALS, null)
            Log.d(TAG, "Raw credentials JSON length: ${json?.length ?: 0}")
            if (json == null) {
                Log.d(TAG, "No credentials found in EncryptedSharedPreferences")
                return emptyList()
            }
            val array = JSONArray(json)
            Log.d(TAG, "Parsed ${array.length()} credentials from JSON")
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading credentials", e)
            emptyList()
        }
    }

    // ── Field Parsing ───────────────────────────────────────

    private fun parseNode(node: AssistStructure.ViewNode, fields: MutableList<ParsedField>) {
        val autofillId = node.autofillId
        if (autofillId != null) {
            val type = detectFieldType(node)
            if (type != null) {
                Log.d(TAG, "Found ${type.name} field: hint=${node.hint}, idEntry=${node.idEntry}, autofillHints=${node.autofillHints?.joinToString()}")
                fields.add(ParsedField(autofillId, type))
            }
        }

        for (i in 0 until node.childCount) {
            parseNode(node.getChildAt(i), fields)
        }
    }

    private fun detectFieldType(node: AssistStructure.ViewNode): FieldType? {
        // Check autofill hints first (most reliable)
        val hints = node.autofillHints
        if (hints != null) {
            for (hint in hints) {
                when {
                    hint.contains("username", true) ||
                    hint.contains("email", true) ||
                    hint.contains("login", true) -> return FieldType.USERNAME

                    hint.contains("password", true) -> return FieldType.PASSWORD
                }
            }
        }

        // Check HTML attributes for web forms
        val htmlInfo = node.htmlInfo
        if (htmlInfo != null) {
            val attrs = htmlInfo.attributes
            if (attrs != null) {
                for (pair in attrs) {
                    val name = pair.first?.toString()?.lowercase() ?: continue
                    val value = pair.second?.toString()?.lowercase() ?: continue
                    if (name == "type") {
                        when (value) {
                            "password" -> return FieldType.PASSWORD
                            "email", "text" -> {
                                // Check name/id attribute too
                                val inputName = getHtmlAttr(attrs, "name")
                                    ?: getHtmlAttr(attrs, "id") ?: ""
                                if (inputName.contains("pass", true)) {
                                    return FieldType.PASSWORD
                                }
                                if (inputName.contains("user", true) ||
                                    inputName.contains("email", true) ||
                                    inputName.contains("login", true)) {
                                    return FieldType.USERNAME
                                }
                                if (value == "email") return FieldType.USERNAME
                            }
                        }
                    }
                }
            }
        }

        // Check input type flags
        val inputType = node.inputType
        if (inputType != 0) {
            if (inputType and android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD != 0 ||
                inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD != 0 ||
                inputType and android.text.InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD != 0 ||
                inputType and android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD != 0) {
                return FieldType.PASSWORD
            }
            if (inputType and android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS != 0 ||
                inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS != 0) {
                return FieldType.USERNAME
            }
        }

        // Check hint text
        val hintText = node.hint?.lowercase() ?: ""
        if (hintText.contains("password") || hintText.contains("পাসওয়ার্ড")) {
            return FieldType.PASSWORD
        }
        if (hintText.contains("email") || hintText.contains("user") ||
            hintText.contains("login") || hintText.contains("ইমেইল")) {
            return FieldType.USERNAME
        }

        // Check id/resource id
        val idEntry = node.idEntry?.lowercase() ?: ""
        if (idEntry.contains("password") || idEntry.contains("passwd")) {
            return FieldType.PASSWORD
        }
        if (idEntry.contains("username") || idEntry.contains("email") || idEntry.contains("login")) {
            return FieldType.USERNAME
        }

        return null
    }

    private fun getHtmlAttr(attrs: List<android.util.Pair<String, String>>, name: String): String? {
        return attrs.firstOrNull { it.first?.toString().equals(name, ignoreCase = true) }?.second?.toString()
    }

    private fun findWebDomain(node: AssistStructure.ViewNode): String? {
        val domain = node.webDomain
        if (!domain.isNullOrEmpty()) return domain
        for (i in 0 until node.childCount) {
            val childDomain = findWebDomain(node.getChildAt(i))
            if (childDomain != null) return childDomain
        }
        return null
    }

    private fun extractDomain(url: String): String {
        return try {
            var domain = url
                .removePrefix("https://")
                .removePrefix("http://")
                .removePrefix("www.")
            val slashIndex = domain.indexOf('/')
            if (slashIndex > 0) domain = domain.substring(0, slashIndex)
            domain
        } catch (e: Exception) {
            url
        }
    }
}

enum class FieldType {
    USERNAME, PASSWORD
}

data class ParsedField(
    val autofillId: AutofillId,
    val type: FieldType
)
