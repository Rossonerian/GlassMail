package com.glassmail.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import kotlinx.coroutines.flow.MutableStateFlow
import com.glassmail.sync.IdleServiceController

class MainActivity : ComponentActivity() {
    private val notificationMessageId = MutableStateFlow<String?>(null)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        notificationMessageId.value = intent.getStringExtra(EXTRA_MESSAGE_ID)
        requestNotificationPermissionOnce()
        val graph = (application as GlassMailApplication).graph
        setContent {
            GlassMailApp(graph, notificationMessageId)
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        notificationMessageId.value = intent.getStringExtra(EXTRA_MESSAGE_ID)
    }

    override fun onStart() {
        super.onStart()
        runCatching { IdleServiceController.start(this) }
    }

    private fun requestNotificationPermissionOnce() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED) {
            val preferences = getSharedPreferences("glassmail_notifications", MODE_PRIVATE)
            if (!preferences.getBoolean("permission_requested", false)) {
                preferences.edit().putBoolean("permission_requested", true).apply()
                ActivityCompat.requestPermissions(this, arrayOf("android.permission.POST_NOTIFICATIONS"), 41)
            }
        }
    }

    companion object { const val EXTRA_MESSAGE_ID = "notification_message_id" }
}
