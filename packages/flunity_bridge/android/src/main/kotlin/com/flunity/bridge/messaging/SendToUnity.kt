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

/**
 * Flutter -> Unity half of the bridge.
 *
 * EVERY branch must terminate the [MethodChannel.Result]. A branch that
 * returns without calling `success` / `error` / `notImplemented` leaves the
 * Dart `await _channel.invokeMethod(...)` pending *forever* — there is no
 * platform-channel timeout. That is not a cosmetic leak: `FlunityInvoker.invoke`
 * awaits the send before it awaits the outlet reply, so a silent send means the
 * reply future is never listened to, its timeout surfaces as an unhandled zone
 * error instead of reaching the caller's try/catch, and the calling widget hangs
 * in its "busy" state with no way out.
 *
 * `UnitySendMessage` is fire-and-forget by design (Unity picks the message up on
 * its next frame), so `success(null)` here means "handed to Unity", not
 * "processed by Unity". Round-trip correlation is the outlet nonce's job.
 */
class SendToUnity: MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            methodNameSendToUnity -> {
                val gameObjectMethodNameData = (call.arguments as List<*>).filterIsInstance<String>()
                if (gameObjectMethodNameData.size < 3) {
                    result.error(
                        "bad_arguments",
                        "sendToUnity expects [gameObject, method, data], got $gameObjectMethodNameData",
                        null)
                    return
                }
                UnityPlayer.UnitySendMessage(
                    gameObjectMethodNameData[0], // Unity game object name
                    gameObjectMethodNameData[1], // Game object method name
                    gameObjectMethodNameData[2]) // Data
                result.success(null)
            }
            methodNamePauseUnity -> {
                UnityPlayerSingleton.getInstance()?.pause()
                result.success(null)
            }
            methodNameResumeUnity -> {
                UnityPlayerSingleton.getInstance()?.resume()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}