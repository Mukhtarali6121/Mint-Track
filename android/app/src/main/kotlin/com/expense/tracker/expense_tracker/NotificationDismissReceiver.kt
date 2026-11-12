package com.expense.tracker.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

class NotificationDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra("notification_id", -1)
        if (notificationId != -1) {
            try {
                NotificationManagerCompat.from(context).cancel(notificationId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
