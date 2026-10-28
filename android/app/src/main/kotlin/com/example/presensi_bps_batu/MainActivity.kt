package com.example.presensi_bps_batu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var cancellation: CancellationSignal? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "presensi/google_identity")
            .setMethodCallHandler { call, result ->
                if (call.method != "authenticate") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("google_busy", "Sign-in is already in progress.", null)
                    return@setMethodCallHandler
                }
                val clientId = call.argument<String>("serverClientId")
                val nonce = call.argument<String>("nonce")
                if (clientId.isNullOrBlank() || nonce == null || !nonce.matches(Regex("[A-Za-z0-9_-]{43}"))) {
                    result.error("google_configuration", "Invalid sign-in configuration.", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                cancellation = CancellationSignal()
                try {
                    val option = GetSignInWithGoogleOption.Builder(clientId).setNonce(nonce).build()
                    val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                    CredentialManager.create(this).getCredentialAsync(
                        this, request, cancellation, ContextCompat.getMainExecutor(this),
                        object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                            override fun onResult(response: GetCredentialResponse) {
                                val reply = pendingResult ?: return
                                pendingResult = null
                                cancellation = null
                                try {
                                    val credential = response.credential
                                    if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                                        reply.error("google_configuration", "Unsupported Google credential.", null)
                                        return
                                    }
                                    reply.success(GoogleIdTokenCredential.createFrom(credential.data).idToken)
                                } catch (_: Exception) {
                                    reply.error("google_configuration", "Invalid Google credential.", null)
                                }
                            }
                            override fun onError(error: GetCredentialException) {
                                finishError(when (error) {
                                    is GetCredentialCancellationException -> "google_canceled"
                                    is NoCredentialException -> "google_no_credential"
                                    is GetCredentialProviderConfigurationException -> "google_configuration"
                                    else -> "google_unavailable"
                                })
                            }
                        }
                    )
                } catch (_: Exception) {
                    finishError("google_configuration")
                }
            }
    }

    private fun finishError(code: String) {
        val reply = pendingResult
        pendingResult = null
        cancellation = null
        reply?.error(code, "Google sign-in did not complete.", null)
    }

    override fun onDestroy() {
        val signal = cancellation
        finishError("google_canceled")
        signal?.cancel()
        super.onDestroy()
    }
}
