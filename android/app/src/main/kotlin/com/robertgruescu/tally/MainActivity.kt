package com.robertgruescu.tally

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var backupFolder: BackupFolder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val folder = BackupFolder(this)
        backupFolder = folder
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BackupFolder.CHANNEL)
            .setMethodCallHandler(folder)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // The folder picker answers here. Handled first so the pending Dart
        // call is always completed, then passed on so the plugins registered
        // by Flutter still see the result they are waiting for.
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
