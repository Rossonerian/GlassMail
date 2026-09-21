package com.glassmail.core.imap

import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailSender
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.SendMailError
import com.glassmail.domain.mail.SendMailResult
import com.glassmail.domain.mail.validateAddresses
import com.glassmail.domain.mail.estimatedOutgoingMessageBytes
import java.util.Properties
import javax.mail.Message
import javax.mail.AuthenticationFailedException
import javax.mail.MessagingException
import javax.mail.Session
import javax.mail.Transport
import javax.mail.Multipart
import javax.activation.DataHandler
import javax.mail.internet.AddressException
import javax.mail.internet.InternetAddress
import javax.mail.internet.MimeMessage
import javax.mail.internet.MimeBodyPart
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlin.coroutines.coroutineContext

interface SmtpCredentialProvider {
    suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T?
}

class GmailSmtpMailSender(
    private val credentialProvider: SmtpCredentialProvider,
    private val host: String = "smtp.gmail.com",
    private val port: Int = 587,
) : MailSender {
    override suspend fun send(account: MailAccount, mail: OutgoingMail): SendMailResult {
        if (mail.accountId != account.accountId || mail.from != account.email || !validateAddresses(mail.to + mail.cc + mail.bcc)) {
            return SendMailResult.Failed(SendMailError.InvalidMessage)
        }
        return try {
            credentialProvider.withCredential(account.accountId) { password ->
                withContext(Dispatchers.IO) {
                    coroutineContext.ensureActive()
                    val properties = Properties().apply {
                        put("mail.smtp.host", host)
                        put("mail.smtp.port", port.toString())
                        put("mail.smtp.auth", "true")
                        put("mail.smtp.starttls.enable", "true")
                        put("mail.smtp.starttls.required", "true")
                        put("mail.smtp.connectiontimeout", TIMEOUT_MILLIS.toString())
                        put("mail.smtp.timeout", TIMEOUT_MILLIS.toString())
                        put("mail.smtp.writetimeout", TIMEOUT_MILLIS.toString())
                    }
                    val session = Session.getInstance(properties)
                    if (estimatedOutgoingMessageBytes(mail) > MAX_ESTIMATED_MESSAGE_BYTES) {
                        return@withContext SendMailResult.Failed(SendMailError.InvalidMessage)
                    }
                    val message = MimeMessage(session).apply {
                        setFrom(InternetAddress(mail.from, true))
                        setRecipients(Message.RecipientType.TO, mail.to.map(::InternetAddress).toTypedArray())
                        if (mail.cc.isNotEmpty()) setRecipients(Message.RecipientType.CC, mail.cc.map(::InternetAddress).toTypedArray())
                        if (mail.bcc.isNotEmpty()) setRecipients(Message.RecipientType.BCC, mail.bcc.map(::InternetAddress).toTypedArray())
                        subject = mail.subject
                        if (mail.attachments.isEmpty()) {
                            setText(mail.body, Charsets.UTF_8.name())
                        } else {
                            val body = MimeBodyPart().apply { setText(mail.body, Charsets.UTF_8.name()) }
                            val multipart: Multipart = javax.mail.internet.MimeMultipart().apply { addBodyPart(body) }
                            mail.attachments.forEach { attachment ->
                                val part = MimeBodyPart()
                                part.dataHandler = DataHandler(object : javax.activation.DataSource {
                                    override fun getInputStream() = attachment.openStream()
                                    override fun getOutputStream() = throw UnsupportedOperationException("read-only attachment")
                                    override fun getContentType() = attachment.mimeType.ifBlank { "application/octet-stream" }
                                    override fun getName() = attachment.fileName
                                })
                                part.fileName = attachment.fileName.replace(Regex("[\\r\\n\\u0000]"), "_")
                                multipart.addBodyPart(part)
                            }
                            setContent(multipart)
                        }
                        mail.inReplyTo?.let { setHeader("In-Reply-To", it) }
                        if (mail.references.isNotEmpty()) setHeader("References", mail.references.joinToString(" "))
                        setHeader("Message-ID", "<${mail.operationId}@glassmail.local>")
                    }
                    session.getTransport("smtp").apply {
                        try {
                            connect(host, port, account.email, String(password))
                            sendMessage(message, message.allRecipients)
                        } finally {
                            close()
                        }
                    }
                    coroutineContext.ensureActive()
                    SendMailResult.Sent
                }
            } ?: SendMailResult.Failed(SendMailError.Authentication)
        } catch (_: CancellationException) {
            throw CancellationException("Send cancelled")
        } catch (_: AddressException) {
            SendMailResult.Failed(SendMailError.InvalidMessage)
        } catch (_: AuthenticationFailedException) {
            SendMailResult.Failed(SendMailError.Authentication)
        } catch (_: MessagingException) {
            SendMailResult.Failed(SendMailError.Network)
        } catch (_: IllegalArgumentException) {
            SendMailResult.Failed(SendMailError.InvalidMessage)
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 30_000
        const val MAX_ESTIMATED_MESSAGE_BYTES = 24L * 1024 * 1024

    }
}
