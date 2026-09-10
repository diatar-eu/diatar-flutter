package diatar.eu

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.File

class MainActivity : FlutterActivity() {
	companion object {
		private const val DIA_SAVE_CHANNEL = "diatar.eu/dia_save"
		private const val ZIP_IMPORT_CHANNEL = "diatar.eu/zip_import"
		private const val EXTERNAL_COMMAND_CHANNEL = "diatar.eu/external_command"
		private const val REQUEST_SAVE_DIA = 6091
		private const val REQUEST_PICK_ZIP = 6092
	}

	private var pendingSaveResult: MethodChannel.Result? = null
	private var pendingSaveBytes: ByteArray? = null
	private var pendingSavePath: String? = null
	private var pendingZipImportResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIA_SAVE_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"saveDiaFile" -> startSaveDiaFlow(call, result)
					"overwriteDiaFile" -> overwriteDiaFile(call, result)
					"saveBackupFile" -> startSaveBackupFlow(call, result)
					else -> result.notImplemented()
				}
			}
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ZIP_IMPORT_CHANNEL)
			.setMethodCallHandler { call, result ->
				if (call.method == "pickZipToCache") {
					startZipImportPick(result)
				} else {
					result.notImplemented()
				}
			}
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXTERNAL_COMMAND_CHANNEL)
			.setMethodCallHandler { call, result ->
				if (call.method == "run") {
					runExternalCommand(call, result)
				} else {
					result.notImplemented()
				}
			}
	}

	private fun runExternalCommand(call: MethodCall, result: MethodChannel.Result) {
		val command = call.argument<String>("command")?.trim()
		if (command.isNullOrEmpty()) {
			result.error("invalid_args", "Missing command.", null)
			return
		}

		try {
			val isBroadcast = command.startsWith("broadcast:", ignoreCase = true)
			val intentSpec = if (isBroadcast) {
				command.substring("broadcast:".length).trim()
			} else {
				command
			}
			if (intentSpec.isEmpty()) {
				result.error("invalid_args", "Missing intent after broadcast prefix.", null)
				return
			}
			val intent = if (intentSpec.startsWith("intent:", ignoreCase = true)) {
				Intent.parseUri(intentSpec, Intent.URI_INTENT_SCHEME)
			} else {
				Intent(Intent.ACTION_VIEW, Uri.parse(intentSpec))
			}
			if (isBroadcast) {
				sendBroadcast(intent)
			} else {
				startActivity(intent)
			}
			result.success(null)
		} catch (e: Exception) {
			result.error(
				"external_command_failed",
				e.localizedMessage ?: e.toString(),
				null,
			)
		}
	}

	private fun startZipImportPick(result: MethodChannel.Result) {
		if (pendingZipImportResult != null) {
			result.error("busy", "Another ZIP import picker is already in progress.", null)
			return
		}
		pendingZipImportResult = result
		val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
			addCategory(Intent.CATEGORY_OPENABLE)
			type = "application/zip"
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
		}
		try {
			startActivityForResult(intent, REQUEST_PICK_ZIP)
		} catch (e: Exception) {
			pendingZipImportResult = null
			result.error("picker_failed", e.localizedMessage ?: e.toString(), null)
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
			addFlags(
				Intent.FLAG_GRANT_READ_URI_PERMISSION or
					Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
					Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
			)
		}

		try {
			startActivityForResult(intent, REQUEST_SAVE_DIA)
		} catch (e: Exception) {
			clearPendingSave()
			result.error("save_dialog_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun overwriteDiaFile(call: MethodCall, result: MethodChannel.Result) {
		val uri = call.argument<String>("uri")
		if (uri.isNullOrEmpty()) {
			result.error("invalid_args", "Missing target URI.", null)
			return
		}
		val bytes = call.argument<ByteArray>("bytes")
		if (bytes == null || bytes.isEmpty()) {
			result.error("invalid_args", "Missing or empty file bytes.", null)
			return
		}
		val targetUri = Uri.parse(uri)
		try {
			val stream = contentResolver.openOutputStream(targetUri, "wt")
				?: throw IOException("Cannot open output stream for target URI.")
			stream.use { out ->
				out.write(bytes)
				out.flush()
			}
			result.success(uri)
		} catch (e: Exception) {
			result.error("overwrite_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun startSaveBackupFlow(call: MethodCall, result: MethodChannel.Result) {
		if (pendingSaveResult != null) {
			result.error("busy", "Another save dialog is already in progress.", null)
			return
		}

		val fileName = (call.argument<String>("fileName") ?: "diatar-backup.zip").trim().ifEmpty {
			"diatar-backup.zip"
		}
		val path = call.argument<String>("path")
		val bytes = call.argument<ByteArray>("bytes")
		if (path != null) {
			if (!java.io.File(path).isFile) {
				result.error("invalid_args", "Backup file not found.", null)
				return
			}
		} else if (bytes == null || bytes.isEmpty()) {
			result.error("invalid_args", "Missing or empty file data.", null)
			return
		}

		pendingSaveResult = result
		pendingSaveBytes = bytes
		pendingSavePath = path

		val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
			addCategory(Intent.CATEGORY_OPENABLE)
			type = "application/zip"
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

		if (requestCode == REQUEST_PICK_ZIP) {
			handleZipImportPick(resultCode, data)
			return
		}
		if (requestCode != REQUEST_SAVE_DIA) {
			return
		}

		val result = pendingSaveResult
		val bytes = pendingSaveBytes
		val path = pendingSavePath
		clearPendingSave()

		if (result == null) {
			return
		}
		if (resultCode != Activity.RESULT_OK || data?.data == null) {
			result.success(null)
			return
		}
		if (bytes == null && path == null) {
			result.error("missing_bytes", "No file data available for save.", null)
			return
		}

		val targetUri = data.data
		try {
			val stream = contentResolver.openOutputStream(targetUri!!)
				?: throw IOException("Cannot open output stream for target URI.")
			stream.use { out ->
				if (path != null) {
					java.io.File(path).inputStream().use { input ->
						input.copyTo(out, bufferSize = 64 * 1024)
					}
				} else {
					out.write(bytes!!)
				}
				out.flush()
			}
			try {
				contentResolver.takePersistableUriPermission(
					targetUri,
					Intent.FLAG_GRANT_READ_URI_PERMISSION or
						Intent.FLAG_GRANT_WRITE_URI_PERMISSION
				)
			} catch (_: Exception) {
				// The provider does not support persisting the grant. The
				// session grant is enough for this save; later overwrites will
				// fall back to the system picker if the grant is gone.
			}
			if (path != null) {
				result.success(targetUri.toString())
			} else {
				result.success(
					mapOf(
						"uri" to targetUri.toString(),
						"displayName" to queryDisplayName(targetUri)
					)
				)
			}
		} catch (e: Exception) {
			result.error("save_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun handleZipImportPick(resultCode: Int, data: Intent?) {
		val result = pendingZipImportResult
		pendingZipImportResult = null
		if (result == null) return
		val uri = data?.data
		if (resultCode != Activity.RESULT_OK || uri == null) {
			result.success(null)
			return
		}
		try {
			contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
		} catch (_: SecurityException) {
			// The one-shot grant from the picker is sufficient for the copy.
		}
		Thread {
			try {
				val displayName = queryDisplayName(uri).ifBlank { "scores.zip" }
				val safeName = displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
				val target = File(cacheDir, "dtz_import_${System.nanoTime()}_$safeName")
				contentResolver.openInputStream(uri)?.use { input ->
					target.outputStream().use { output ->
						input.copyTo(output, bufferSize = 64 * 1024)
					}
				} ?: throw IOException("Cannot open the selected ZIP file.")
				runOnUiThread { result.success(target.absolutePath) }
			} catch (e: Exception) {
				runOnUiThread {
					result.error("zip_copy_failed", e.localizedMessage ?: e.toString(), null)
				}
			}
		}.start()
	}

	private fun queryDisplayName(uri: Uri): String {
		return try {
			contentResolver.query(uri, null, null, null, null)?.use { cursor ->
				if (cursor.moveToFirst()) {
					val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
					if (index >= 0) cursor.getString(index) else null
				} else {
					null
				}
			} ?: ""
		} catch (_: Exception) {
			""
		}
	}

	private fun clearPendingSave() {
		pendingSaveResult = null
		pendingSaveBytes = null
		pendingSavePath = null
	}
}
