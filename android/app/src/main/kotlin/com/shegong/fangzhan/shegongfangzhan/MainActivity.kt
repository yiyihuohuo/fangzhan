package com.shegong.fangzhan.shegongfangzhan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.shegong.fangzhan.shegongfangzhan.FrpManager

class MainActivity : FlutterActivity() {
    private var frpThread: Thread? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frp_channel").setMethodCallHandler { call, result ->
            when (call.method) {
                "startFrp" -> {
                    val cfgContent = call.argument<String>("config") ?: ""
                    if (cfgContent.isBlank()) {
                        result.error("invalid_config", "Config is empty", null)
                        return@setMethodCallHandler
                    }
                    if (frpThread?.isAlive == true) {
                        result.success("already_running")
                        return@setMethodCallHandler
                    }
                    frpThread = Thread {
                        FrpManager.startClient(this@MainActivity, cfgContent)
                    }.apply { start() }
                    result.success("started")
                }
                "stop" -> {
                    Thread {
                        FrpManager.stopClient()
                    }.start()
                    result.success("stopping")
                    frpThread = null
                }
                "getLogs" -> {
                    Thread {
                        val logs = FrpManager.getLogs()
                        runOnUiThread { result.success(logs) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
