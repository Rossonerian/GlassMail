package com.glassmail.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val graph = (application as GlassMailApplication).graph
        setContent {
            MaterialTheme {
                GlassMailApp(graph)
            }
        }
    }
}
