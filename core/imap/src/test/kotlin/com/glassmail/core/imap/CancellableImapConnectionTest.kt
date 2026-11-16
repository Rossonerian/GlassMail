package com.glassmail.core.imap

import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.concurrent.CountDownLatch
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
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
