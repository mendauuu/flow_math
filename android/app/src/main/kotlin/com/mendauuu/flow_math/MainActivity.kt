package com.mendauuu.flow_math

import android.content.ComponentName
import android.content.pm.PackageManager
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter and lets the user switch the app's home-screen icon.
 *
 * Each icon is an <activity-alias> in AndroidManifest.xml and exactly one of
 * them is enabled. A new choice is applied when the app goes to the
 * background, so switching never closes the screen the user is looking at.
 */
class MainActivity : FlutterActivity() {

    // Icon id (used by Dart) -> activity-alias name in AndroidManifest.xml.
    private val aliases = linkedMapOf(
        "moon" to "IconMoon", // enabled in the manifest = default
        "sprout" to "IconSprout",
        "forest" to "IconForest",
        "mint" to "IconMint",
    )
    private val defaultIcon = "moon"
    private var pendingIcon: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow_math/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> result.success(pendingIcon ?: currentIcon())
                    "set" -> {
                        val id = call.argument<String>("id")
                        if (id == null || id !in aliases) {
                            result.error("unknown_icon", "No app icon called $id", null)
                        } else {
                            pendingIcon = if (id == currentIcon()) null else id
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Keep the screen awake during focus sessions (phone as a desk timer).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow_math/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") == true
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        applyPendingIcon()
    }

    private fun component(alias: String): ComponentName {
        // Aliases are declared relative to the Kotlin package (the namespace).
        val namespace = javaClass.name.substringBeforeLast('.')
        return ComponentName(packageName, "$namespace.$alias")
    }

    private fun currentIcon(): String {
        for ((id, alias) in aliases) {
            when (packageManager.getComponentEnabledSetting(component(alias))) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> return id
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT ->
                    if (id == defaultIcon) return id
            }
        }
        return defaultIcon
    }

    private fun applyPendingIcon() {
        val id = pendingIcon ?: return
        pendingIcon = null
        try {
            // Enable the new icon first, so the app always has a launcher entry.
            packageManager.setComponentEnabledSetting(
                component(aliases.getValue(id)),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for ((other, alias) in aliases) {
                if (other == id) continue
                packageManager.setComponentEnabledSetting(
                    component(alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        } catch (e: Exception) {
            Log.w("FlowMath", "Could not switch app icon", e)
        }
    }
}
