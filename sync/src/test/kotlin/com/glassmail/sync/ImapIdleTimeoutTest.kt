package com.glassmail.sync

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ImapIdleTimeoutTest {
    @Test
    fun onTimeoutIsDeclaredWithAndroid15Signature() {
        val method = ImapIdleService::class.java.getDeclaredMethod(
            "onTimeout",
            Int::class.javaPrimitiveType,
            Int::class.javaPrimitiveType,
        )

        assertEquals("onTimeout", method.name)
        assertEquals(Void.TYPE, method.returnType)
    }

    @Test
    fun handleIdleTimeoutCancelsScopeClearsJobsStopsForegroundAndCallsStopSelf() {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)
        val childJob = scope.launch { awaitCancellation() }
        val jobs = mutableMapOf<String, Job>("acc-1" to childJob)
        val calls = mutableListOf<String>()

        handleIdleTimeout(
            scope = scope,
            jobs = jobs,
            stopForeground = { calls += "stopForeground" },
            stopSelf = { calls += "stopSelf" },
        )

        assertFalse(scope.isActive)
        assertTrue(childJob.isCancelled)
        assertTrue(jobs.isEmpty())
        assertEquals(listOf("stopForeground", "stopSelf"), calls)
    }
}
