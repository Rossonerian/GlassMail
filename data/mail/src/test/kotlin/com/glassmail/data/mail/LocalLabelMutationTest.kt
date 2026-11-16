package com.glassmail.data.mail

import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MessageLabelEntity
import com.glassmail.domain.mail.MailMutation
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class LocalLabelMutationTest {
    @Test fun `offline add and remove keep all displayed memberships and canonical labels consistent`() = runTest {
        val mail = mockk<MailDao>()
        val memberships = linkedMapOf(
            "a:INBOX" to MailboxMessageEntity("a:INBOX", 7, "gmail:a:1", "\\Seen", "Project Alpha\u001FWork"),
            "a:Sent" to MailboxMessageEntity("a:Sent", 200, "gmail:a:1", "\\Seen", "Project Alpha\u001FWork"),
        )
        val labels = mutableSetOf("Project Alpha", "Work")
        coEvery { mail.membershipsForMessage("gmail:a:1") } coAnswers { memberships.values.toList() }
        coEvery { mail.upsertMailboxMessages(any()) } coAnswers {
            firstArg<List<MailboxMessageEntity>>().forEach { memberships[it.mailboxId] = it }
        }
        coEvery { mail.upsertLabels(any()) } coAnswers { labels.addAll(firstArg<List<MessageLabelEntity>>().map { it.label }); Unit }
        coEvery { mail.removeLabel(any(), any()) } coAnswers { labels.remove(secondArg<String>()); Unit }
        applyLocalLabel(mail, MailMutation.Label("a", "gmail:a:1", null, "Follow Up", true))
        assertEquals(setOf("Project Alpha", "Work", "Follow Up"), labels)
        memberships.values.forEach {
            assertEquals(labels, it.labels.toLabels().toSet())
            assertEquals("\\Seen", it.flags)
        }
        // Repeated add remains a set, and removal treats a label containing spaces as one value.
        applyLocalLabel(mail, MailMutation.Label("a", "gmail:a:1", null, "Follow Up", true))
        applyLocalLabel(mail, MailMutation.Label("a", "gmail:a:1", null, "Project Alpha", false))
        assertEquals(setOf("Follow Up", "Work"), labels)
        memberships.values.forEach { assertEquals(labels, it.labels.toLabels().toSet()) }
    }
}
