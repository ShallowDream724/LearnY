package com.learny.learn_y

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import android.webkit.CookieManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "learny/auth_cookies")
            .setMethodCallHandler { call, result ->
                if (call.method != "getCookieHeader") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")
                val uri = url?.let { Uri.parse(it) }
                val hosts = setOf("learn.tsinghua.edu.cn", "id.tsinghua.edu.cn",
                    "oauth.tsinghua.edu.cn", "webvpn.tsinghua.edu.cn", "zhjw.cic.tsinghua.edu.cn")
                if (uri?.scheme != "https" || uri.host !in hosts) {
                    result.error("invalid_origin", "Unsupported authentication origin", null)
                } else {
                    result.success(CookieManager.getInstance().getCookie(url))
                }
            }
    }
}
