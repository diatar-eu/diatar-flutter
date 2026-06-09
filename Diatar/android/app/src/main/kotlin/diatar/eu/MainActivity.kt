package diatar.eu

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
	companion object {
		private const val DIA_SAVE_CHANNEL = "diatar.eu/dia_save"
		private const val REQUEST_SAVE_DIA = 6091
	}

	private var pendingSaveResult: MethodChannel.Result? = null
	private var pendingSaveBytes: ByteArray? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIA_SAVE_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"saveDiaFile" -> startSaveDiaFlow(call, result)
					else -> result.notImplemented()
				}
			}
	}

	private fun startSaveDiaFlow(call: MethodCall, result: MethodChannel.Result) {
		if (pendingSaveResult != null) {
			result.error("busy", "Another save dialog is already in progress.", null)
			return
		}

		val fileName = (call.argument<String>("fileName") ?: "sorrend.dia").trim().ifEmpty {
			"sorrend.dia"
		}
		val bytes = call.argument<ByteArray>("bytes")
		if (bytes == null || bytes.isEmpty()) {
			result.error("invalid_args", "Missing or empty file bytes.", null)
			return
		}

		pendingSaveResult = result
		pendingSaveBytes = bytes

		val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
			addCategory(Intent.CATEGORY_OPENABLE)
			type = "application/octet-stream"
			putExtra(Intent.EXTRA_TITLE, fileName)
		}

		try {
			startActivityForResult(intent, REQUEST_SAVE_DIA)
		} catch (e: Exception) {
			clearPendingSave()
			result.error("save_dialog_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode != REQUEST_SAVE_DIA) {
			return
		}

		val result = pendingSaveResult
		val bytes = pendingSaveBytes
		clearPendingSave()

		if (result == null) {
			return
		}
		if (resultCode != Activity.RESULT_OK || data?.data == null) {
			result.success(null)
			return
		}
		if (bytes == null) {
			result.error("missing_bytes", "No file data available for save.", null)
			return
		}

		val targetUri = data.data
		try {
			val stream = contentResolver.openOutputStream(targetUri!!)
				?: throw IOException("Cannot open output stream for target URI.")
			stream.use { out ->
				out.write(bytes)
				out.flush()
			}
			result.success(targetUri.toString())
		} catch (e: Exception) {
			result.error("save_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun clearPendingSave() {
		pendingSaveResult = null
		pendingSaveBytes = null
	}
}
