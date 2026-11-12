package com.expense.tracker.expense_tracker

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val TAG = "MainActivity"
    private val CHANNEL = "com.expense.tracker/sms_transaction"
    private var methodChannel: MethodChannel? = null
    private var pendingTransaction: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        val isTransaction = intent.getBooleanExtra("is_transaction_detected", false)
        val action = intent.action
        Log.d(TAG, "handleIntent: isTransaction=$isTransaction, action=$action")

        if (isTransaction || action == SmsBroadcastReceiver.ACTION_ADD_TRANSACTION) {
            val notificationId = intent.getIntExtra("notification_id", -1)
            if (notificationId != -1) {
                try {
                    NotificationManagerCompat.from(this).cancel(notificationId)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            val txnData = mapOf(
                "amount" to intent.getDoubleExtra("amount", 0.0),
                "type" to (intent.getStringExtra("type") ?: "expense"),
                "bank" to (intent.getStringExtra("bank") ?: "Bank"),
                "title" to (intent.getStringExtra("title") ?: ""),
                "account" to (intent.getStringExtra("account") ?: ""),
                "timestamp" to intent.getLongExtra("timestamp", System.currentTimeMillis()),
                "sms_body" to (intent.getStringExtra("sms_body") ?: "")
            )

            // Always store in pendingTransaction so Flutter can pull it reliably
            pendingTransaction = txnData

            // Also push to active method channel if ready
            methodChannel?.invokeMethod("onTransactionDetected", txnData)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingTransaction" -> {
                        Log.d(TAG, "getPendingTransaction requested, returning: $pendingTransaction")
                        val pending = pendingTransaction
                        pendingTransaction = null
                        result.success(pending)
                    }
                    "clearPendingTransaction" -> {
                        pendingTransaction = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
