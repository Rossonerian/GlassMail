package com.glassmail.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.glassmail.domain.mail.MailListItem

class NotificationCoordinator(private val context: Context, private val preferences: AppearancePreferences) {
    init {
        if (Build.VERSION.SDK_INT >= 26) context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "New mail", NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    fun onNewMessages(messages: List<MailListItem>) {
        if (messages.isEmpty() || !NotificationManagerCompat.from(context).areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, "android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED)
        ) return
        messages.take(MAX_BATCH).forEach { message ->
            val accountId = accountIdForMessage(message.messageId) ?: return@forEach
            val intent = Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_MESSAGE_ID, message.messageId)
            val pending = PendingIntent.getActivity(context, stableId(message.messageId), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val previews = preferences.read().showNotificationPreviews
            NotificationManagerCompat.from(context).notify(accountTag(accountId), stableId(message.messageId), NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_glerio)
                .setContentTitle(if (previews) message.sender else "New email")
                .setContentText(if (previews) message.subject.ifBlank { message.preview.take(80) } else "Open glerio to view it")
                .setContentIntent(pending).setAutoCancel(true).setGroup(accountTag(accountId))
                .addExtras(Bundle().apply { putString(EXTRA_ACCOUNT_ID, accountId) })
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build())
        }
    }

    fun cancelForAccount(accountId: String, legacyMessageIds: List<String> = emptyList()) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val legacyIds = legacyMessageIds.map(::stableId).toSet()
        manager.activeNotifications.forEach { posted ->
            val belongsToAccount = posted.tag == accountTag(accountId) ||
                posted.notification.extras.getString(EXTRA_ACCOUNT_ID) == accountId
            val legacyMail = posted.tag == null && posted.notification.group == GROUP_KEY && posted.id in legacyIds
            if (belongsToAccount || legacyMail) manager.cancel(posted.tag, posted.id)
        }
    }

    companion object {
        const val CHANNEL_ID = "new-mail"
        const val GROUP_KEY = "glassmail-mail"
        private const val EXTRA_ACCOUNT_ID = "glassmail.account_id"
        private const val MAX_BATCH = 5
        private fun stableId(id: String) = id.hashCode() and 0x7fffffff
        internal fun accountTag(accountId: String) = "$GROUP_KEY:$accountId"
        internal fun accountIdForMessage(messageId: String): String? {
            val parts = messageId.split(':', limit = 3)
            return parts.getOrNull(1)?.takeIf { it.isNotBlank() && parts.size == 3 && parts[0] in setOf("gmail", "imap") }
        }
    }
}
