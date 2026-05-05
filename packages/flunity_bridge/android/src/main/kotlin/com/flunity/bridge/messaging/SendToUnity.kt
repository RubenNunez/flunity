// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.messaging

import com.flunity.bridge.constants.NativeConstants.Companion.methodNamePauseUnity
import com.flunity.bridge.constants.NativeConstants.Companion.methodNameResumeUnity
import com.flunity.bridge.constants.NativeConstants.Companion.methodNameSendToUnity
import com.flunity.bridge.unity.UnityPlayerSingleton
import com.unity3d.player.UnityPlayer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SendToUnity: MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            methodNameSendToUnity -> {
                val gameObjectMethodNameData = (call.arguments as List<*>).filterIsInstance<String>()
                UnityPlayer.UnitySendMessage(
                    gameObjectMethodNameData[0], // Unity game object name
                    gameObjectMethodNameData[1], // Game object method name
                    gameObjectMethodNameData[2]) // Data
            }
            methodNamePauseUnity -> {
                UnityPlayerSingleton.getInstance()?.pause()
            }
            methodNameResumeUnity -> {
                UnityPlayerSingleton.getInstance()?.resume()
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}