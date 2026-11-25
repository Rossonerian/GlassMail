package com.glassmail.core.imap

import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.concurrent.CountDownLatch
import javax.net.ssl.SSLParameters
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class CancellableImapConnectionTest {
    @Test(timeout = 5_000) fun `cancellation closes socket and promptly releases a blocking read`() = runBlocking {
        ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { server ->
            Socket(InetAddress.getLoopbackAddress(), server.localPort).use { socket ->
                server.accept().use {
                    socket.soTimeout = 26 * 60 * 1_000
                    val reading = CompletableDeferred<Unit>()
                    val failure = CompletableDeferred<Throwable>()
                    val job = launch(Dispatchers.IO) {
                        try {
                            withConnectionCancellation(socket) {
                                reading.complete(Unit)
                                socket.getInputStream().read() // Server deliberately never sends data.
                            }
                        } catch (error: Throwable) {
                            failure.complete(error)
                            throw error
                        }
                    }
                    try {
                        withTimeout(1_500) {
                            reading.await()
                            job.cancelAndJoin()
                            assertTrue(failure.await() is CancellationException)
                        }
                        assertTrue(socket.isClosed)
                    } finally {
                        socket.close()
                        job.cancelAndJoin()
                    }
                }
            }
        }
    }

    @Test fun `configureImapTlsParameters restricts protocols to TLS 1_2 and 1_3 and preserves HTTPS endpoint identification`() {
        val params = SSLParameters().apply {
            cipherSuites = arrayOf("TLS_AES_128_GCM_SHA256")
            protocols = arrayOf("SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2")
        }

        val configured = configureImapTlsParameters(
            params = params,
            supportedProtocols = arrayOf("SSLv2Hello", "SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2", "TLSv1.3"),
        )

        assertSame(params, configured)
        assertEquals("HTTPS", configured.endpointIdentificationAlgorithm)
        assertArrayEquals(arrayOf("TLSv1.2", "TLSv1.3"), configured.protocols)
        assertArrayEquals(arrayOf("TLS_AES_128_GCM_SHA256"), configured.cipherSuites)
    }

    @Test fun `configureImapTlsParameters drops legacy protocols when no TLS 1_2 or 1_3 is supported`() {
        val params = SSLParameters().apply {
            protocols = arrayOf("TLSv1", "TLSv1.1")
        }

        val configured = configureImapTlsParameters(
            params = params,
            supportedProtocols = arrayOf("SSLv3", "TLSv1", "TLSv1.1"),
        )

        assertEquals("HTTPS", configured.endpointIdentificationAlgorithm)
        assertArrayEquals(emptyArray<String>(), configured.protocols)
    }

    @Test(timeout = 5_000) fun `withConnection maps handshake failure without cancellation to Transport`() = runBlocking {
        ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { server ->
            val acceptJob = launch(Dispatchers.IO) {
                server.accept().use {
                    // Close immediately before TLS handshake completes so socket read fails with IOException.
                }
            }
            val client = GmailImapClient(
                host = InetAddress.getLoopbackAddress().hostAddress ?: "127.0.0.1",
                port = server.localPort,
                connectTimeoutMillis = 1_500,
                readTimeoutMillis = 1_500,
            )
            try {
                client.fetchStorageQuota("user@example.com", charArrayOf('p', 'w'))
                throw AssertionError("Expected ImapException.Transport")
            } catch (error: ImapException.Transport) {
                assertTrue(
                    "Expected IOException in cause chain, got ${error.cause}",
                    generateSequence<Throwable>(error.cause) { it.cause }.any { it is IOException },
                )
            } finally {
                acceptJob.cancelAndJoin()
            }
        }
    }

    @Test(timeout = 5_000) fun `withConnection cancellation during handshake throws CancellationException`() = runBlocking {
        ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { server ->
            val accepted = CompletableDeferred<Unit>()
            val holdOpen = CountDownLatch(1)
            val acceptJob = launch(Dispatchers.IO) {
                server.accept().use {
                    accepted.complete(Unit)
                    holdOpen.await()
                }
            }
            val failure = CompletableDeferred<Throwable>()
            val client = GmailImapClient(
                host = InetAddress.getLoopbackAddress().hostAddress ?: "127.0.0.1",
                port = server.localPort,
                connectTimeoutMillis = 5_000,
                readTimeoutMillis = 25_000,
            )
            val job = launch(Dispatchers.IO) {
                try {
                    client.fetchStorageQuota("user@example.com", charArrayOf('p', 'w'))
                } catch (error: Throwable) {
                    failure.complete(error)
                    throw error
                }
            }
            try {
                withTimeout(1_500) {
                    accepted.await()
                    job.cancelAndJoin()
                    assertTrue(failure.await() is CancellationException)
                }
            } finally {
                holdOpen.countDown()
                acceptJob.cancelAndJoin()
                job.cancelAndJoin()
            }
        }
    }
}

class CancellableImapConnectionHelperTest {
    @Test(timeout = 5_000) fun `cancellation unblocks a blocking connection and rethrows as cancellation`() = runBlocking {
        val reading = CompletableDeferred<Unit>()
        val failure = CompletableDeferred<Throwable>()
        val closed = CountDownLatch(1)
        val connection = AutoCloseable { closed.countDown() }
        val job = launch(Dispatchers.IO) {
            try {
                withConnectionCancellation(connection) {
                    reading.complete(Unit)
                    closed.await()
                    throw ImapException.Transport(SocketException("Socket closed"))
                }
            } catch (error: Throwable) {
                failure.complete(error)
                throw error
            }
        }
        try {
            withTimeout(1_500) {
                reading.await()
                job.cancelAndJoin()
                assertTrue(failure.await() is CancellationException)
            }
        } finally {
            connection.close()
            job.cancelAndJoin()
        }
    }

    @Test fun `transport failure without cancellation remains a transport failure`() = runBlocking {
        val expected = ImapException.Transport(IOException("connection lost"))
        try {
            withConnectionCancellation(AutoCloseable {}) { throw expected }
            throw AssertionError("Expected transport failure")
        } catch (actual: ImapException.Transport) {
            assertSame(expected, actual)
        }
    }
}
