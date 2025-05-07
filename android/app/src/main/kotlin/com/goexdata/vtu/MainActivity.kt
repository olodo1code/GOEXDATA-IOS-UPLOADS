package com.goexdata.vtu

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Main FlutterActivity
class MainActivity : FlutterActivity() {
    private var fileChooserResult: MethodChannel.Result? = null

    fun getFileChooserResult(): MethodChannel.Result? = fileChooserResult
    fun setFileChooserResult(result: MethodChannel.Result?) {
        fileChooserResult = result
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 9001) {
            if (resultCode == RESULT_OK) {
                val fileUri = data?.data
                fileChooserResult?.success(fileUri?.toString())
            } else {
                fileChooserResult?.success(null)
            }
            fileChooserResult = null
        }
    }
}

// Standalone FileChooserActivity to handle file selection using ActivityResult API
class FileChooserActivity : AppCompatActivity() {

    private val fileChooserLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val data = result.data
        val resultCode = result.resultCode
        val returnIntent = Intent()
        if (resultCode == Activity.RESULT_OK && data != null) {
            returnIntent.data = data.data
            setResult(Activity.RESULT_OK, returnIntent)
        } else {
            setResult(Activity.RESULT_CANCELED)
        }
        finish()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        fileChooserLauncher.launch(intent)
    }
}

// Plugin implementation to bridge Flutter <-> Android file chooser
class WebViewFileChooserPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: MainActivity? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "webview_file_chooser")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openFileChooser") {
            val intent = Intent(activity, FileChooserActivity::class.java)
            activity?.setFileChooserResult(result)
            activity?.startActivityForResult(intent, 9001)
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as MainActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as MainActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}
