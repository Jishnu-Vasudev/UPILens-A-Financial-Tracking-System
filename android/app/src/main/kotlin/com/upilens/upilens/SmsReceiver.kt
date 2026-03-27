package com.upilens.upilens

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.telephony.SmsMessage
import io.flutter.plugin.common.EventChannel

/**
 * BroadcastReceiver for incoming SMS. Forwards matching UPI SMS to Flutter
 * via the EventChannel sink registered by MainActivity.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        // Bank sender IDs to filter against
        private val UPI_SENDERS = setOf(
            "HDFCBK", "SBIINB", "ICICIB", "AXISBK", "PAYTM",
            "GPAY", "OKAXIS", "OKSBI", "OKHDFCBANK", "YESBNK",
            "HDFCBANK", "SBIPSG", "ICICIBANK", "AXISBANK",
            "PYTM", "VK-HDFCBK", "VM-SBIINB"
        )

        var eventSink: EventChannel.EventSink? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val bundle: Bundle = intent.extras ?: return
        val pdus = bundle["pdus"] as? Array<*> ?: return
        val format = bundle.getString("format") ?: "3gpp"

        for (pdu in pdus) {
            val smsMessage = SmsMessage.createFromPdu(pdu as ByteArray, format)
            val sender = smsMessage.originatingAddress ?: continue
            val body = smsMessage.messageBody ?: continue
            val timestamp = smsMessage.timestampMillis

            // Check if the sender looks like a UPI bank
            val senderUpper = sender.uppercase()
            val isUpiSender = UPI_SENDERS.any { senderUpper.contains(it) }
            val isUpiBody = body.contains("UPI", ignoreCase = true) ||
                            body.contains("debited", ignoreCase = true) ||
                            body.contains("credited", ignoreCase = true) ||
                            body.contains("VPA", ignoreCase = true)

            if (isUpiSender || isUpiBody) {
                val smsData = mapOf(
                    "address" to sender,
                    "body" to body,
                    "date" to timestamp.toString()
                )
                eventSink?.success(smsData)
            }
        }
    }
}
