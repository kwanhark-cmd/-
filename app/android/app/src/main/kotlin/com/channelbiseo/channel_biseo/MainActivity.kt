package com.channelbiseo.channel_biseo

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 앱 꾸미기: 홈 화면(런처) 아이콘 바꾸기, 이름·그림으로 홈 화면 바로가기 만들기.
class MainActivity : FlutterActivity() {
    private val icons = listOf("blue", "purple", "green", "orange", "pink")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "channel_biseo/look").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "setLauncherIcon" -> {
                        setLauncherIcon(call.argument<String>("id") ?: "blue")
                        result.success(null)
                    }
                    "pinShortcut" -> result.success(
                        pinShortcut(call.argument<String>("label") ?: "", call.argument<ByteArray>("png") ?: ByteArray(0)),
                    )
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("look", e.message, null)
            }
        }
    }

    /// 고른 아이콘의 별칭만 켜고 나머지는 끈다. (앱은 닫지 않음)
    private fun setLauncherIcon(id: String) {
        if (id !in icons) return
        for (i in icons) {
            val alias = ComponentName(this, "$packageName.Launcher${i.replaceFirstChar { it.uppercase() }}")
            val state = if (i == id) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            packageManager.setComponentEnabledSetting(alias, state, PackageManager.DONT_KILL_APP)
        }
    }

    /// 사용자가 정한 이름·그림으로 홈 화면 바로가기 (안드로이드 8 이상, 런처가 지원할 때).
    private fun pinShortcut(label: String, png: ByteArray): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || png.isEmpty()) return false
        val sm = getSystemService(ShortcutManager::class.java) ?: return false
        if (!sm.isRequestPinShortcutSupported) return false
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return false
        val intent = Intent(this, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
        val info = ShortcutInfo.Builder(this, "custom-home")
            .setShortLabel(label.ifBlank { "채널 관리 비서" }.take(25))
            .setIcon(Icon.createWithBitmap(bitmap))
            .setIntent(intent)
            .build()
        return sm.requestPinShortcut(info, null)
    }
}
