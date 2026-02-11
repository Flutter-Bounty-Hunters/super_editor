package com.flutterbountyhunters.superkeyboard.super_keyboard

import android.util.Log
import io.flutter.plugin.common.MethodChannel

object SuperKeyboardLog {
    private var isLoggingEnabled: Boolean = false
    private var reportTo: MethodChannel? = null

    fun enable(reportTo: MethodChannel?) {
        isLoggingEnabled = true
        this.reportTo = reportTo
    }

    fun disable() {
        isLoggingEnabled = false
        reportTo = null
    }

    fun v(tag: String, message: String) {
        if (isLoggingEnabled) {
            if (reportTo == null) {
                Log.v(tag, message)
            } else {
                reportToDart("v", message);
            }
        }
    }

    fun d(tag: String, message: String) {
        if (isLoggingEnabled) {
            if (reportTo == null) {
                Log.d(tag, message)
            } else {
                reportToDart("d", message);
            }
        }
    }

    fun i(tag: String, message: String) {
        if (isLoggingEnabled) {
            if (reportTo == null) {
                Log.i(tag, message)
            } else {
                reportToDart("i", message);
            }
        }
    }

    fun w(tag: String, message: String) {
        if (isLoggingEnabled) {
            if (reportTo == null) {
                Log.w(tag, message)
            } else {
                reportToDart("w", message);
            }
        }
    }

    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (isLoggingEnabled) {
            if (reportTo == null) {
                Log.e(tag, message, throwable)
            } else {
                reportToDart("e", message);
            }
        }
    }

    private fun reportToDart(level: String, message: String) {
        reportTo!!.invokeMethod(
            "log",
            mapOf(
                "level" to level,
                "message" to message,
            )
        )
    }
}