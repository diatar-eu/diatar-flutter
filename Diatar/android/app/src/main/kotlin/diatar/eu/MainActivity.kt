package diatar.eu

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
	companion object {
		private const val DIA_SAVE_CHANNEL = "diatar.eu/dia_save"
		private const val REQUEST_SAVE_DIA = 6091
		private const val REQUEST_PICK_DIA_FOLDER = 6092
	}

	private var pendingSaveResult: MethodChannel.Result? = null
	private var pendingSaveBytes: ByteArray? = null
	private var pendingSavePath: String? = null
	private var pendingFolderResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIA_SAVE_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"saveDiaFile" -> startSaveDiaFlow(call, result)
					"saveBackupFile" -> startSaveBackupFlow(call, result)
					"pickDiaSaveFolder" -> startPickDiaSaveFolder(call, result)
					"diaFileExists" -> checkDiaFileExists(call, result)
					"writeDiaFileToFolder" -> writeDiaFileToFolder(call, result)
					else -> result.notImplemented()
				}
			}
	}

	private fun startSaveDiaFlow(call: MethodCall, result: MethodChannel.Result) {
		if (pendingSaveResult != null || pendingFolderResult != null) {
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

	private fun startSaveBackupFlow(call: MethodCall, result: MethodChannel.Result) {
		if (pendingSaveResult != null || pendingFolderResult != null) {
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

	private fun startPickDiaSaveFolder(call: MethodCall, result: MethodChannel.Result) {
		if (pendingFolderResult != null || pendingSaveResult != null) {
			result.error("busy", "Another save dialog is already in progress.", null)
			return
		}

		pendingFolderResult = result

		val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
			addFlags(
				Intent.FLAG_GRANT_READ_URI_PERMISSION
					or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
					or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
			)
			val initialUri = call.argument<String>("initialUri")
			if (!initialUri.isNullOrEmpty()) {
				try {
					putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialUri))
				} catch (_: Exception) {
					// Ignore invalid initial URI.
				}
			}
		}

		try {
			startActivityForResult(intent, REQUEST_PICK_DIA_FOLDER)
		} catch (e: Exception) {
			pendingFolderResult = null
			result.error("folder_dialog_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun checkDiaFileExists(call: MethodCall, result: MethodChannel.Result) {
		val treeUriString = call.argument<String>("treeUri")
		val fileName = call.argument<String>("fileName")?.trim().orEmpty()
		if (treeUriString.isNullOrEmpty() || fileName.isEmpty()) {
			result.error("invalid_args", "Missing treeUri or fileName.", null)
			return
		}
		try {
			val treeUri = Uri.parse(treeUriString)
			val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
			val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
			var exists = false
			contentResolver.query(
				childrenUri,
				arrayOf(
					DocumentsContract.Document.COLUMN_DOCUMENT_ID,
					DocumentsContract.Document.COLUMN_DISPLAY_NAME
				),
				null,
				null,
				null
			)?.use { cursor ->
				while (cursor.moveToNext()) {
					val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
					if (nameIndex >= 0 && fileName == cursor.getString(nameIndex)) {
						exists = true
						break
					}
				}
			}
			result.success(exists)
		} catch (e: Exception) {
			result.error("query_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun writeDiaFileToFolder(call: MethodCall, result: MethodChannel.Result) {
		val treeUriString = call.argument<String>("treeUri")
		val fileName = call.argument<String>("fileName")?.trim().orEmpty()
		val bytes = call.argument<ByteArray>("bytes")
		if (treeUriString.isNullOrEmpty() || fileName.isEmpty() || bytes == null || bytes.isEmpty()) {
			result.error("invalid_args", "Missing treeUri, fileName, or bytes.", null)
			return
		}
		try {
			val treeUri = Uri.parse(treeUriString)
			val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
			val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
			var targetDocId: String? = null
			contentResolver.query(
				childrenUri,
				arrayOf(
					DocumentsContract.Document.COLUMN_DOCUMENT_ID,
					DocumentsContract.Document.COLUMN_DISPLAY_NAME
				),
				null,
				null,
				null
			)?.use { cursor ->
				while (cursor.moveToNext()) {
					val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
					if (nameIndex >= 0 && fileName == cursor.getString(nameIndex)) {
						val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
						targetDocId = if (idIndex >= 0) cursor.getString(idIndex) else null
						break
					}
				}
			}
			val targetUri: Uri
			if (targetDocId != null) {
				targetUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, targetDocId)
			} else {
				targetUri = DocumentsContract.createDocument(
					contentResolver,
					treeUri,
					"application/octet-stream",
					fileName
				) ?: throw IOException("Cannot create document with name $fileName.")
			}
			contentResolver.openOutputStream(targetUri, "wt")?.use { out ->
				out.write(bytes)
				out.flush()
			} ?: throw IOException("Cannot open output stream for $fileName.")
			result.success(targetUri.toString())
		} catch (e: Exception) {
			result.error("save_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode == REQUEST_PICK_DIA_FOLDER) {
			val folderResult = pendingFolderResult
			pendingFolderResult = null
			if (folderResult == null) {
				return
			}
			if (resultCode != Activity.RESULT_OK || data?.data == null) {
				folderResult.success(null)
				return
			}
			val treeUri = data.data!!
			try {
				contentResolver.takePersistableUriPermission(
					treeUri,
					Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
				)
			} catch (_: Exception) {
				// Non-persistable grants are tolerated.
			}
			folderResult.success(treeUri.toString())
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
			result.success(targetUri.toString())
		} catch (e: Exception) {
			result.error("save_failed", e.localizedMessage ?: e.toString(), null)
		}
	}

	private fun clearPendingSave() {
		pendingSaveResult = null
		pendingSaveBytes = null
		pendingSavePath = null
	}
}
