package com.glassmail.core.security

import android.content.Context
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties

interface CredentialStore {
    suspend fun store(accountId: String, credential: CharArray)
    suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T?
    suspend fun delete(accountId: String)
}

class AndroidKeystoreCredentialStore(context: Context) : CredentialStore {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    override suspend fun store(accountId: String, credential: CharArray) {
        require(accountId.isNotBlank())
        val plainBytes = String(credential).encodeToByteArray()
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key()) }
            val sealed = cipher.iv + cipher.doFinal(plainBytes)
            preferences.edit().putString(preferenceKey(accountId), Base64.encodeToString(sealed, Base64.NO_WRAP)).commit()
        } finally {
            plainBytes.fill(0)
            credential.fill('\u0000')
        }
    }

    override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? {
        val stored = preferences.getString(preferenceKey(accountId), null) ?: return null
        val sealed = Base64.decode(stored, Base64.NO_WRAP)
        val plainBytes = try {
            val iv = sealed.copyOfRange(0, IV_BYTES)
            Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, iv))
            }.doFinal(sealed, IV_BYTES, sealed.size - IV_BYTES)
        } finally {
            sealed.fill(0)
        }
        val credential = plainBytes.decodeToString().toCharArray()
        try {
            return block(credential)
        } finally {
            plainBytes.fill(0)
            credential.fill('\u0000')
        }
    }

    override suspend fun delete(accountId: String) {
        preferences.edit().remove(preferenceKey(accountId)).commit()
    }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        return (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.secretKey ?: createKey()
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
    }
}
