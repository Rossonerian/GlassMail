package com.glassmail.core.imap

import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.OutgoingAttachment
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.SendMailError
import com.glassmail.domain.mail.SendMailResult
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class GmailSmtpMailSenderTest {
    private val account = MailAccount("a", "me@example.com", "IDLE")
    private val provider = object : SmtpCredentialProvider {
        override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? = block(charArrayOf('x'))
    }

    @Test fun `invalid outgoing recipient is rejected before transport`() = runBlocking {
        val result = GmailSmtpMailSender(provider).send(account, OutgoingMail("op", "a", account.email, listOf("bad"), subject = "x", body = "x"))
        assertEquals(SendMailResult.Failed(SendMailError.InvalidMessage), result)
    }

    @Test fun `missing credential becomes authentication failure`() = runBlocking {
        val missing = object : SmtpCredentialProvider {
            override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? = null
        }
        val result = GmailSmtpMailSender(missing).send(account, OutgoingMail("op", "a", account.email, listOf("to@example.com"), subject = "x", body = "x"))
        assertEquals(SendMailResult.Failed(SendMailError.Authentication), result)
    }

    @Test fun `oversized outgoing message returns InvalidMessage error`() = runBlocking {
        val oversizedMail = OutgoingMail(
            operationId = "op",
            accountId = "a",
            from = account.email,
            to = listOf("to@example.com"),
            subject = "Large",
            body = "x",
            attachments = listOf(
                OutgoingAttachment(
                    fileName = "big.bin",
                    mimeType = "application/octet-stream",
                    sizeBytes = 25L * 1024 * 1024,
                    openStream = { java.io.ByteArrayInputStream(ByteArray(0)) }
                )
            )
        )
        val result = GmailSmtpMailSender(provider).send(account, oversizedMail)
        assertEquals(SendMailResult.Failed(SendMailError.InvalidMessage), result)
    }
}
