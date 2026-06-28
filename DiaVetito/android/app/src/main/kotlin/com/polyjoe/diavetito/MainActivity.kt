package com.polyjoe.diavetito

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val SYSTEM_CHANNEL = "com.polyjoe.diavetito/system"
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"requestShutdown" -> result.success(requestShutdown())
					else -> result.notImplemented()
				}
			}
	}

	private fun requestShutdown(): Boolean {
		return try {
			val intent = Intent("android.intent.action.ACTION_REQUEST_SHUTDOWN").apply {
				putExtra("android.intent.extra.KEY_CONFIRM", false)
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			startActivity(intent)
			true
		} catch (_: Exception) {
			false
		}
	}
}
