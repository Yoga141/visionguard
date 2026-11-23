package id.ac.itk.visionguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Meneruskan status layar ke Dart lewat EventChannel `visionguard/screen_state`
 * ("off" / "on"). Pemantauan dihentikan saat layar mati (KDL-02, DOCS_SPEC §16 #11).
 */
class MainActivity : FlutterActivity() {
    private var screenReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "visionguard/screen_state")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            when (intent?.action) {
                                Intent.ACTION_SCREEN_OFF -> events.success("off")
                                Intent.ACTION_SCREEN_ON -> events.success("on")
                            }
                        }
                    }
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_SCREEN_OFF)
                        addAction(Intent.ACTION_SCREEN_ON)
                    }
                    // Broadcast sistem; tidak perlu diekspor ke aplikasi lain.
                    applicationContext.registerReceiver(receiver, filter)
                    screenReceiver = receiver
                }

                override fun onCancel(arguments: Any?) {
                    unregister()
                }
            })
    }

    override fun onDestroy() {
        unregister()
        super.onDestroy()
    }

    private fun unregister() {
        screenReceiver?.let {
            try {
                applicationContext.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        screenReceiver = null
    }
}
