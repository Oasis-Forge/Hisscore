package com.oasisforge.hisscore

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands the Dart side any challenge link the app was opened with.
 *
 * Flutter's own deep linking is deliberately not switched on: it turns
 * an incoming link into a route, and this app has no router. A channel
 * that passes the URI across as a string leaves the decision about what
 * to do with it in the game, where it belongs.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /**
     * A link that arrived before Dart was listening.
     *
     * Both ends of the app's life need this. On a cold start the intent
     * exists long before the first `initialLink` call, and on a warm one
     * `onNewIntent` can land while the engine is being rebuilt.
     */
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = linkFrom(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Answered once. The game starts the challenge on the
                    // way through, so handing the same link back after a
                    // rebuild would restart a run the player is in.
                    "initialLink" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Without this, getIntent() keeps returning the one the activity
        // was launched with, and a second link would be read as the first.
        setIntent(intent)
        val link = linkFrom(intent) ?: return
        val live = channel
        if (live == null) pending = link else live.invokeMethod("link", link)
    }

    private fun linkFrom(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_VIEW) intent.dataString else null

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val CHANNEL = "com.oasisforge.hisscore/links"
    }
}
