package com.glassmail.core.imap

import com.glassmail.domain.mail.OutgoingAttachment
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.SendMailError
import com.glassmail.domain.mail.SendMailResult
import java.io.IOException
import javax.mail.MessagingException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SendReliabilityTest {
    private val account = com.glassmail.domain.mail.MailAccount("a", "me@gmail.com", "READY")
    private val provider = object : SmtpCredentialProvider {
        override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? = block("pw".toCharArray())
    }

    @Test fun `stable message id survives encoding so remote drafts can be replaced and deleted`() {
        val mail = OutgoingMail("draft-42", "a", account.email, listOf("to@example.com"), subject = "Hi", body = "Body")
        repeat(2) {
            val raw = String(Rfc822MessageEncoder.encode(mail), Charsets.ISO_8859_1)
            assertTrue(raw, raw.contains("Message-ID: <draft-42@glassmail.local>"))
            assertTrue(raw.contains("Date: "))
        }
    }

    @Test fun `unreadable attachment fails before submission and is reported as an attachment problem`() = runBlocking {
        val mail = OutgoingMail(
            "op", "a", account.email, listOf("to@example.com"), subject = "x", body = "x",
            attachments = listOf(OutgoingAttachment("a.bin", "application/octet-stream", 10) { throw IOException("revoked") }),
        )
        assertEquals(SendMailResult.Failed(SendMailError.Attachment), GmailSmtpMailSender(provider).send(account, mail))
    }

    @Test fun `io failure inside a messaging exception is recognised as a possible partial submission`() {
        assertTrue(MessagingException("wrapped", IOException("reset")).hasIoCause())
        assertTrue(MessagingException("outer", MessagingException("inner", java.net.SocketTimeoutException())).hasIoCause())
        assertFalse(MessagingException("535 auth").hasIoCause())
    }
}
