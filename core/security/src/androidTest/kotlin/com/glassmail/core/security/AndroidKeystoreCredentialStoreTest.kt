package com.glassmail.core.security

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import android.content.Context

@RunWith(AndroidJUnit4::class)
class AndroidKeystoreCredentialStoreTest {

    private lateinit var credentialStore: AndroidKeystoreCredentialStore
    private val accountId = "test_account_id"
    private val context = ApplicationProvider.getApplicationContext<Context>()

    @Before
    fun setup() {
        credentialStore = AndroidKeystoreCredentialStore(context)
    }

    @After
    fun teardown() = runBlocking {
        credentialStore.delete(accountId)
        // Clean up SharedPreferences for isolation
        context.getSharedPreferences("glassmail.credentials.v1", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test
    fun storeAndRetrieveCredentialSuccessfully() = runBlocking {
        val originalPassword = "my_super_secret_password"
        val charArray = originalPassword.toCharArray()

        // Store credential
        credentialStore.store(accountId, charArray)

        // Retrieve credential
        val result = credentialStore.withCredential(accountId) { retrievedCharArray ->
            String(retrievedCharArray)
        }

        assertEquals(originalPassword, result)
    }

    @Test
    fun missingCredentialReturnsNull() = runBlocking {
        val result = credentialStore.withCredential("non_existent_account") {
            "should_not_reach_here"
        }

        assertNull(result)
    }

    @Test
    fun deleteCredentialSuccessfully() = runBlocking {
        val password = "password_to_delete"
        credentialStore.store(accountId, password.toCharArray())

        // Ensure it was saved
        val resultBeforeDelete = credentialStore.withCredential(accountId) { String(it) }
        assertEquals(password, resultBeforeDelete)

        // Delete credential
        credentialStore.delete(accountId)

        // Try to retrieve it again
        val resultAfterDelete = credentialStore.withCredential(accountId) { String(it) }
        assertNull(resultAfterDelete)
    }

    @Test
    fun credentialStringIsZeroedOutAfterStoring() = runBlocking {
        val charArray = "secret".toCharArray()

        credentialStore.store(accountId, charArray)

        // After storing, the passed char array should be filled with '\u0000'
        assertTrue(charArray.all { it == '\u0000' })
    }

    @Test
    fun credentialStringIsZeroedOutAfterRetrieval() = runBlocking {
        val password = "secret_password"
        credentialStore.store(accountId, password.toCharArray())

        var capturedArray: CharArray? = null

        credentialStore.withCredential(accountId) { retrievedCharArray ->
            capturedArray = retrievedCharArray
            assertEquals(password, String(retrievedCharArray))
            // While inside the block, the array should have the correct password
            Unit
        }

        // After the block has executed, the array should be zeroed out
        assertTrue("Array should be zeroed out", capturedArray!!.all { it == '\u0000' })
    }
}
