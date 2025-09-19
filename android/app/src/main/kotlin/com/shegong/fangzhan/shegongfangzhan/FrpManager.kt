package com.shegong.fangzhan.shegongfangzhan

import android.content.Context
import android.util.Log
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.thread

object FrpManager {
    private const val TAG = "FrpManager"
    private const val CFG_NAME = "frpc.toml"
    private const val BIN_NAME = "libfrpc.so" // we treat it as executable

    private var process: Process? = null
    private val logQueue = LinkedBlockingQueue<String>()
    private var logThread: Thread? = null

    private val ANSI_REGEX = Regex("\\u001B\\[[0-9;]*[mK]")

    fun startClient(context: Context, cfgContent: String) {
        Log.i(TAG, "startClient called with length=${cfgContent.length}")
        if (process?.isAlive == true) return

        // 1. write config
        val fullCfg = buildString {
            append(cfgContent.trim())
            appendLine()
            appendLine()
            appendLine("[log]")
            appendLine("to = \"console\"")
            appendLine("level = \"debug\"")
        }
        val cfgFile = File(context.filesDir, CFG_NAME)
        cfgFile.writeText(fullCfg)

        // 2. directly use the bundled native library path (read-only, exec allowed)
        val binFile = File(context.applicationInfo.nativeLibraryDir, BIN_NAME)
        if (!binFile.canExecute()) {
            // set exec bit just in case
            binFile.setExecutable(true)
        }

        try {
            process = ProcessBuilder(
                binFile.absolutePath, "-c", cfgFile.absolutePath
            )
                .redirectErrorStream(true)
                .start().also { proc ->
                    // read stdout in background
                    logThread = thread(name = "frpc-log-reader") {
                        try {
                            InputStreamReader(proc.inputStream).buffered().useLines { seq ->
                                seq.forEach { line ->
                                    val clean = ANSI_REGEX.replace(line, "")
                                    logQueue.offer(clean)
                                    Log.d("frpc", clean)
                                }
                            }
                        } catch (e: java.io.InterruptedIOException) {
                            // expected when stream is closed during stop
                        } catch (e: Exception) {
                            Log.w(TAG, "log reader terminated: ${e.message}")
                        }
                    }
                }
            Log.i(TAG, "frpc process started")
        } catch (e: Exception) {
            Log.e(TAG, "start frpc failed", e)
        }
    }

    fun stopClient() {
        Log.i(TAG, "stopClient called")
        process?.let { proc ->
            try { proc.inputStream.close() } catch (_: Exception) {}
            try { proc.outputStream.close() } catch (_: Exception) {}
            proc.destroy() // SIGTERM – frpc traps and exits gracefully
            // wait up to 5s, else kill
            if (!proc.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)) {
                proc.destroyForcibly()
            }
        }
        logThread?.interrupt()
        logThread = null
        process = null
    }

    fun getLogs(): String {
        val sb = StringBuilder()
        while (true) {
            val line = logQueue.poll() ?: break
            sb.appendLine(line)
        }
        return sb.toString()
    }
} 