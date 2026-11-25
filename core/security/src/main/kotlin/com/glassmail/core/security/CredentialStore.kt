package com.glassmail.core.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.StandardCharsets
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.security.ProviderException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

interface CredentialStore {
    suspend fun store(accountId: String, credential: CharArray)
    suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T?
    suspend fun delete(accountId: String)
}

internal fun encodeCredential(chars: CharArray): ByteArray {
    val buf = StandardCharsets.UTF_8.encode(CharBuffer.wrap(chars))
    try {
        return buf.array().copyOfRange(
            buf.arrayOffset() + buf.position(),
            buf.arrayOffset() + buf.limit(),
        )
    } finally {
        buf.array().fill(0)
    }
}

internal fun decodeCredential(bytes: ByteArray): CharArray {
    val buf = StandardCharsets.UTF_8.decode(ByteBuffer.wrap(bytes))
    try {
        return buf.array().copyOfRange(
            buf.arrayOffset() + buf.position(),
            buf.arrayOffset() + buf.limit(),
        )
    } finally {
        buf.array().fill('\u0000')
    }
}

class AndroidKeystoreCredentialStore(context: Context) : CredentialStore {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    override suspend fun store(accountId: String, credential: CharArray) {
        try {
            require(accountId.isNotBlank())
            withContext(Dispatchers.IO) {
                val plainBytes = encodeCredential(credential)
                try {
                    val cipher = Cipher.getInstance(TRANSFORMATION).apply {
                        init(Cipher.ENCRYPT_MODE, getOrCreateKey())
                    }
                    val sealed = cipher.iv + cipher.doFinal(plainBytes)
                    preferences.edit()
                        .putString(preferenceKey(accountId), Base64.encodeToString(sealed, Base64.NO_WRAP))
                        .commit()
                } finally {
                    plainBytes.fill(0)
                }
            }
        } finally {
            credential.fill('\u0000')
        }
    }

    override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? {
        var credential: CharArray? = null
        try {
            credential = withContext(Dispatchers.IO) {
                val stored = preferences.getString(preferenceKey(accountId), null) ?: return@withContext null
                val sealed = try {
                    Base64.decode(stored, Base64.NO_WRAP)
                } catch (_: IllegalArgumentException) {
                    return@withContext null
                }
                if (sealed.size <= IV_BYTES + TAG_BITS / 8) {
                    sealed.fill(0)
                    return@withContext null
                }
                val plainBytes = try {
                    val key = existingKey() ?: return@withContext null
                    val iv = sealed.copyOfRange(0, IV_BYTES)
                    Cipher.getInstance(TRANSFORMATION).apply {
                        init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, iv))
                    }.doFinal(sealed, IV_BYTES, sealed.size - IV_BYTES)
                } catch (_: GeneralSecurityException) {
                    return@withContext null
                } catch (_: ProviderException) {
                    return@withContext null
                } finally {
                    sealed.fill(0)
                }
                try {
                    decodeCredential(plainBytes).also { credential = it }
                } finally {
                    plainBytes.fill(0)
                }
            }
            val cred = credential ?: return null
            return block(cred)
        } finally {
            credential?.fill('\u0000')
        }
    }

    override suspend fun delete(accountId: String) {
        withContext(Dispatchers.IO) {
            preferences.edit().remove(preferenceKey(accountId)).commit()
        }
    }

    private fun existingKey(): SecretKey? = synchronized(keyLock) {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.secretKey
    }

    private fun getOrCreateKey(): SecretKey = synchronized(keyLock) {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.secretKey ?: createKey()
    }

    private fun createKey(): SecretKey = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
        init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        generateKey()
    }

    private fun preferenceKey(accountId: String) = "credential.$accountId"

    private companion object {
        const val PREFERENCES = "glassmail.credentials.v1"
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "glassmail.app-password.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_BYTES = 12
        const val TAG_BITS = 128
        private val keyLock = Any()
    }
}
