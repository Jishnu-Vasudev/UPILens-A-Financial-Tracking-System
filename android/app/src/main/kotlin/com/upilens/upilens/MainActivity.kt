package com.upilens.upilens

import android.content.ContentResolver
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL = "upi_lens/sms"
    private val SMS_STREAM_CHANNEL = "upi_lens/sms_stream"

    private val UPI_SENDERS = setOf(
        "HDFCBK", "SBIINB", "ICICIB", "AXISBK", "PAYTM",
        "GPAY", "OKAXIS", "OKSBI", "OKHDFCBANK", "YESBNK",
        "HDFCBANK", "SBIPSG", "ICICIBANK", "AXISBANK",
        "PYTM", "VK-HDFCBK", "VM-SBIINB"
    )

    private var smsReceiver: SmsReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel: getSmsHistory ─────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSmsHistory" -> {
                        try {
                            val smsList = readSmsInbox()
                            result.success(smsList)
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── EventChannel: live SMS stream ────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_STREAM_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    SmsReceiver.eventSink = events
                    smsReceiver = SmsReceiver()
                    val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
                    filter.priority = 1000
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(smsReceiver, filter, RECEIVER_EXPORTED)
                    } else {
                        registerReceiver(smsReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    SmsReceiver.eventSink = null
                    smsReceiver?.let { unregisterReceiver(it) }
                    smsReceiver = null
                }
            })
    }

    /**
     * Queries content://sms/inbox for the last 90 days and returns
     * matching UPI bank SMS as List<Map<String, String>>.
     */
    private fun readSmsInbox(): List<Map<String, String>> {
        val smsList = mutableListOf<Map<String, String>>()
        val cr: ContentResolver = contentResolver

        // 90 days ago in milliseconds
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -90)
        val cutoffMs = calendar.timeInMillis

        val uri: Uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("address", "body", "date")
        val selection = "date >= ?"
        val selectionArgs = arrayOf(cutoffMs.toString())
        val sortOrder = "date DESC"

        var cursor: Cursor? = null
        try {
            cursor = cr.query(uri, projection, selection, selectionArgs, sortOrder)
            cursor?.let {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")

                while (it.moveToNext()) {
                    val address = it.getString(addressIdx) ?: continue
                    val body = it.getString(bodyIdx) ?: continue
                    val date = it.getString(dateIdx) ?: continue

                    val addrUpper = address.uppercase()
                    val isUpiSender = UPI_SENDERS.any { s -> addrUpper.contains(s) }
                    val isUpiBody = body.contains("UPI", ignoreCase = true) ||
                                   body.contains("debited", ignoreCase = true) ||
                                   body.contains("credited", ignoreCase = true) ||
                                   body.contains("VPA", ignoreCase = true)

                    if (isUpiSender || isUpiBody) {
                        smsList.add(
                            mapOf("address" to address, "body" to body, "date" to date)
                        )
                    }
                }
            }
        } finally {
            cursor?.close()
        }
        return smsList
    }
}
