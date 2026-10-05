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

    @Test fun `Gmail SMTP deletes remote draft without appending a second Sent copy`() = runBlocking {
        for (host in listOf("smtp.gmail.com", "smtp.googlemail.com", "SMTP.GMAIL.COM.", "relay.gmail.com")) {
            var deleted = 0
            var appended = 0
            fileAcceptedSmtpMessage(host, deleteDraft = { deleted++ }, appendSent = { appended++ })
            assertEquals("draft deletion for $host", 1, deleted)
            assertEquals("Sent APPEND for $host", 0, appended)
        }
    }

    @Test fun `non Gmail SMTP still appends Sent even if draft deletion fails`() = runBlocking {
        var appended = 0
        fileAcceptedSmtpMessage("smtp.example.com", deleteDraft = { error("draft deletion failed") }, appendSent = { appended++ })
        assertEquals(1, appended)
    }

    @Test fun `accepted SMTP filing failures remain best effort`() = runBlocking {
        fileAcceptedSmtpMessage("smtp.example.com", deleteDraft = {}, appendSent = { error("APPEND failed") })
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
