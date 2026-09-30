package com.robertgruescu.tally

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException

/**
 * A folder on the phone that the app may keep writing to, chosen once by the
 * user.
 *
 * The app's own snapshots live in its private storage, which Android deletes
 * along with the app. That makes them useless for the one case the user cares
 * about most: uninstalling and reinstalling. A folder picked through the
 * Storage Access Framework survives that, stays visible in Files, and can be
 * copied to a computer.
 *
 * Written against [DocumentsContract] directly rather than through a plugin.
 * The third-party SAF wrappers are thin over these same five calls and are
 * variously unmaintained; a dependency that stops being updated is a liability
 * in something the user's records depend on.
 *
 * The grant is revoked when the app is uninstalled, so after a reinstall the
 * user points at the folder once more. That is a platform rule and no amount
 * of code gets around it.
 */
class BackupFolder(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "tally/backup_folder"
        private const val PICK_FOLDER = 4711
        private const val MIME = "application/json"
    }

    private var pending: MethodChannel.Result? = null

    private val resolver: ContentResolver get() = activity.contentResolver

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickFolder" -> pickFolder(result)
                "hasAccess" -> result.success(hasAccess(call.argument<String>("tree")!!))
                "displayName" -> result.success(displayName(call.argument<String>("tree")!!))
                "write" -> {
                    write(
                        call.argument<String>("tree")!!,
                        call.argument<String>("name")!!,
                        call.argument<String>("content")!!,
                    )
                    result.success(true)
                }
                "list" -> result.success(list(call.argument<String>("tree")!!))
                "read" -> result.success(read(call.argument<String>("uri")!!))
                "delete" -> result.success(delete(call.argument<String>("uri")!!))
                "openBackupSettings" -> {
                    openBackupSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Every one of these is a safety net, never the thing the user
            // asked for. A folder that has gone away must surface as a failed
            // backup, not as a crash on top of whatever they were doing.
            result.error("backup_folder", e.message, null)
        }
    }

    // ----------------------------------------------------------------- picking

    private fun pickFolder(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A folder picker is already open.", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        activity.startActivityForResult(intent, PICK_FOLDER)
    }

    /** Called by [MainActivity]; true when this was our request. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FOLDER) return false
        val result = pending ?: return true
        pending = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Backing out of the picker is an answer, not a failure.
            result.success(null)
            return true
        }

        // Without this the grant dies with the activity, and the next daily
        // snapshot would silently have nowhere to go.
        resolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        result.success(uri.toString())
        return true
    }

    private fun hasAccess(tree: String): Boolean {
        val uri = Uri.parse(tree)
        return resolver.persistedUriPermissions.any {
            it.uri == uri && it.isWritePermission && it.isReadPermission
        }
    }

    /** The folder's name as the user would recognise it, for the settings row. */
    private fun displayName(tree: String): String? {
        val uri = Uri.parse(tree)
        val doc = DocumentsContract.buildDocumentUriUsingTree(
            uri,
            DocumentsContract.getTreeDocumentId(uri),
        )
        resolver.query(
            doc,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null,
        )?.use { if (it.moveToFirst()) return it.getString(0) }
        return null
    }

    // ------------------------------------------------------------------ files

    private fun childrenUri(tree: Uri): Uri = DocumentsContract.buildChildDocumentsUriUsingTree(
        tree,
        DocumentsContract.getTreeDocumentId(tree),
    )

    private fun parentUri(tree: Uri): Uri = DocumentsContract.buildDocumentUriUsingTree(
        tree,
        DocumentsContract.getTreeDocumentId(tree),
    )

    /** The document with this exact name, or null. */
    private fun findChild(tree: Uri, name: String): Uri? {
        resolver.query(
            childrenUri(tree),
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == name) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                }
            }
        }
        return null
    }

    private fun write(tree: String, name: String, content: String) {
        val treeUri = Uri.parse(tree)
        // Reusing an existing document rather than always creating: SAF
        // answers a second `createDocument` with "tally (1).json", and a
        // folder that grows a new numbered copy every day is not a backup,
        // it is a mess the user has to clean up.
        val target = findChild(treeUri, name)
            ?: DocumentsContract.createDocument(resolver, parentUri(treeUri), MIME, name)
            ?: throw FileNotFoundException("Could not create $name")

        // "wt" truncates. Without the t a shorter snapshot would leave the
        // tail of the previous, longer one behind and produce invalid JSON.
        resolver.openOutputStream(target, "wt").use { stream ->
            stream ?: throw FileNotFoundException("Could not open $name")
            stream.write(content.toByteArray(Charsets.UTF_8))
            stream.flush()
        }
    }

    private fun list(tree: String): List<Map<String, Any?>> {
        val treeUri = Uri.parse(tree)
        val out = mutableListOf<Map<String, Any?>>()
        resolver.query(
            childrenUri(treeUri),
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                DocumentsContract.Document.COLUMN_SIZE,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(1)
                if (!name.endsWith(".json")) continue
                out.add(
                    mapOf(
                        "uri" to DocumentsContract
                            .buildDocumentUriUsingTree(treeUri, cursor.getString(0)).toString(),
                        "name" to name,
                        "modified" to cursor.getLong(2),
                        "size" to cursor.getLong(3),
                    ),
                )
            }
        }
        return out
    }

    private fun read(uri: String): String =
        resolver.openInputStream(Uri.parse(uri)).use { stream ->
            stream ?: throw FileNotFoundException(uri)
            stream.readBytes().toString(Charsets.UTF_8)
        }

    private fun delete(uri: String): Boolean =
        DocumentsContract.deleteDocument(resolver, Uri.parse(uri))

    // --------------------------------------------------------------- settings

    /**
     * Opens the system page holding the Google account backup switch.
     *
     * The app cannot turn it on; only the user can, and only here. Falling
     * back through three intents because the exact screen has moved between
     * versions and between manufacturer skins.
     */
    private fun openBackupSettings() {
        val candidates = listOf(
            Intent("android.settings.BACKUP_AND_RESET_SETTINGS"),
            Intent(Settings.ACTION_PRIVACY_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                activity.startActivity(intent)
                return
            } catch (_: Exception) {
                // Try the next, broader one.
            }
        }
    }
}
