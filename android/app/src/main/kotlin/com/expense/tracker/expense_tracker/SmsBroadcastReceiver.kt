package com.expense.tracker.expense_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Locale
import java.util.regex.Pattern

class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "transaction_detection_channel"
        const val CHANNEL_NAME = "Transaction Detection"
        const val ACTION_ADD_TRANSACTION = "com.expense.tracker.ADD_TRANSACTION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages: Array<SmsMessage>? = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (e: Exception) {
            null
        }

        if (messages.isNullOrEmpty()) return

        val fullBody = StringBuilder()
        var sender = ""

        for (sms in messages) {
            fullBody.append(sms.messageBody)
            if (sender.isEmpty() && sms.originatingAddress != null) {
                sender = sms.originatingAddress ?: ""
            }
        }

        val bodyText = fullBody.toString()
        val parsed = parseTransaction(sender, bodyText) ?: return

        showTransactionNotification(context, parsed, bodyText)
    }

    data class ParsedTransaction(
        val amount: Double,
        val type: String, // "expense" or "income"
        val bank: String,
        val title: String,
        val account: String
    )

    private fun parseTransaction(sender: String, body: String): ParsedTransaction? {
        val lower = body.lowercase(Locale.ROOT)

        // 1. Exclude non-transaction messages (OTP, security codes, loan spam, mandates, failed)
        val exclusionKeywords = listOf(
            "otp", "verification code", "one time password", "secret code",
            "mandate", "pre-approved", "apply now", "loan offer", "click here",
            "failed", "declined", "unsuccessful", "requested money", "request to pay"
        )
        for (kw in exclusionKeywords) {
            if (lower.contains(kw)) return null
        }

        // 2. Identify transaction type
        val expenseKeywords = listOf("debited", "spent", "purchase", "withdrawn", "paid", "sent to", "deducted", "transferred to", "trf to")
        val incomeKeywords = listOf("credited", "received", "deposited", "added to", "refund")

        val isExpense = expenseKeywords.any { lower.contains(it) }
        val isIncome = incomeKeywords.any { lower.contains(it) }

        if (!isExpense && !isIncome) return null
        val type = if (isExpense) "expense" else "income"

        // 3. Extract Amount
        val amountRegex = Pattern.compile(
            "(?:(?:inr|rs\\.?|₹)\\s*([0-9,]+(?:\\.[0-9]{1,2})?))|(?:(?:debited|credited|spent|withdrawn|paid|received|added|deposited)\\s*(?:by|with|for)?\\s*(?:inr|rs\\.?|₹)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?))",
            Pattern.CASE_INSENSITIVE
        )
        val matcher = amountRegex.matcher(body)
        var amount: Double? = null

        if (matcher.find()) {
            val amtStr = (matcher.group(1) ?: matcher.group(2))?.replace(",", "")?.trim()
            amount = amtStr?.toDoubleOrNull()
        }

        if (amount == null || amount <= 0.0) {
            // Secondary regex if primary didn't catch it
            val secondaryRegex = Pattern.compile("(?:rs|inr|₹)\\s*([0-9]+(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
            val secMatcher = secondaryRegex.matcher(body)
            if (secMatcher.find()) {
                amount = secMatcher.group(1)?.toDoubleOrNull()
            }
        }

        if (amount == null || amount <= 0.0) return null

        // 4. Extract Bank Name
        val bank = identifyBank(sender, body)

        // 5. Extract Account Mask (e.g. A/c **1234)
        val accountRegex = Pattern.compile("(?:a/c|acct|acc|card|ending)\\s*(?:no\\.?)?\\s*[*xX]*([0-9]{3,4})", Pattern.CASE_INSENSITIVE)
        val accMatcher = accountRegex.matcher(body)
        val account = if (accMatcher.find()) {
            accMatcher.group(1) ?: ""
        } else {
            ""
        }

        // 6. Extract Merchant or Recipient Name
        val title = extractTitle(body, type, bank)

        return ParsedTransaction(
            amount = amount,
            type = type,
            bank = bank,
            title = title,
            account = account
        )
    }

    private fun identifyBank(sender: String, body: String): String {
        val s = (sender + " " + body).uppercase(Locale.ROOT)
        return when {
            s.contains("HDFC") -> "HDFC Bank"
            s.contains("SBI") || s.contains("STATE BANK") -> "State Bank of India"
            s.contains("ICICI") -> "ICICI Bank"
            s.contains("AXIS") -> "Axis Bank"
            s.contains("KOTAK") -> "Kotak Mahindra"
            s.contains("PAYTM") -> "Paytm Payments Bank"
            s.contains("BOB") || s.contains("BARODA") -> "Bank of Baroda"
            s.contains("PNB") || s.contains("PUNJAB") -> "Punjab National Bank"
            s.contains("CANARA") || s.contains("CANBNK") -> "Canara Bank"
            s.contains("YES BANK") || s.contains("YESBNK") -> "Yes Bank"
            s.contains("INDUS") -> "IndusInd Bank"
            s.contains("UNION") -> "Union Bank"
            s.contains("IDFC") -> "IDFC FIRST Bank"
            s.contains("FEDERAL") -> "Federal Bank"
            s.contains("RBL") -> "RBL Bank"
            s.contains("CITI") -> "Citi Bank"
            s.contains("AMEX") || s.contains("AMERICAN EXPRESS") -> "American Express"
            s.contains("AU BANK") || s.contains("AUFIN") -> "AU Small Finance Bank"
            else -> "Bank"
        }
    }

    private fun extractTitle(body: String, type: String, bank: String): String {
        // Look for "to VPA abc@upi", "at Starbucks", "to John", "trf to John"
        val vpaRegex = Pattern.compile("(?:to\\s+vpa|vpa)\\s+([a-zA-Z0-9._-]+@[a-zA-Z0-9]+)", Pattern.CASE_INSENSITIVE)
        val vpaMatcher = vpaRegex.matcher(body)
        if (vpaMatcher.find()) {
            return vpaMatcher.group(1)?.trim() ?: ""
        }

        val merchantRegex = Pattern.compile("(?:at|to|trf to|info:?)\\s+([A-Za-z0-9 &._-]{3,25})", Pattern.CASE_INSENSITIVE)
        val mMatcher = merchantRegex.matcher(body)
        if (mMatcher.find()) {
            val candidate = mMatcher.group(1)?.trim() ?: ""
            // Ensure candidate isn't just an account number or keyword
            if (!candidate.matches(Regex("^[0-9]+$")) && !candidate.lowercase(Locale.ROOT).contains("vpa")) {
                return candidate
            }
        }

        return if (type == "expense") "Payment at $bank" else "Deposit to $bank"
    }

    private fun showTransactionNotification(context: Context, txn: ParsedTransaction, rawBody: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        // Create Channel for Android 8.0+ (Oreo)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when a new bank transaction is detected"
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notificationId = (System.currentTimeMillis() % 100000).toInt()

        // 1. Add Intent: launches MainActivity to open the "Quick Add" Bottom Sheet
        val addIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_ADD_TRANSACTION
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("is_transaction_detected", true)
            putExtra("amount", txn.amount)
            putExtra("type", txn.type)
            putExtra("bank", txn.bank)
            putExtra("title", txn.title)
            putExtra("account", txn.account)
            putExtra("timestamp", System.currentTimeMillis())
            putExtra("sms_body", rawBody)
            putExtra("notification_id", notificationId)
        }

        val addPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Dismiss Intent: invokes NotificationDismissReceiver to cancel notification
        val dismissIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
            putExtra("notification_id", notificationId)
        }

        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 1,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val formattedAmt = String.format(Locale.getDefault(), "₹%.2f", txn.amount)
        val typeLabel = if (txn.type == "expense") "Debit" else "Credit"
        val actionLabel = if (txn.type == "expense") "expense" else "income"

        val bodyText = "We noticed a $typeLabel of $formattedAmt from ${txn.bank}.\nDo you want to record this $actionLabel?"

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("💳 New Transaction Detected")
            .setContentText("We noticed a $typeLabel of $formattedAmt from ${txn.bank}.")
            .setStyle(NotificationCompat.BigTextStyle().bigText(bodyText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(addPendingIntent) // Tapping the notification opens "Add to Tracker"
            .addAction(
                android.R.drawable.ic_input_add,
                "+ Add to Tracker",
                addPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss",
                dismissPendingIntent
            )

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        } catch (e: SecurityException) {
            e.printStackTrace()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
