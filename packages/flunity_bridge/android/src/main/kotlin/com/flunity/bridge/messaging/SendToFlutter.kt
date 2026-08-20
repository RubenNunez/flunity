// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.messaging

import android.os.Handler
import android.os.Looper
import com.flunity.bridge.constants.NativeConstants.Companion.methodNameSendToFlutter
import io.flutter.plugin.common.MethodChannel

/**
 * Static bridge invoked by Unity (via [AndroidJavaClass]) to forward a message
 * to Flutter over the [MethodChannel].
 *
 * The Unity-side helper looks like:
 * ```csharp
 * using (var nativeAPI = new AndroidJavaClass("com.flunity.bridge.messaging.SendToFlutter")) {
 *     nativeAPI.CallStatic("sendToFlutter", json);
 * }
 * ```
 *
 * THREADING: Unity calls in from its own `UnityMain` thread, but
 * `MethodChannel.invokeMethod` is `@UiThread`. Calling it from any other
 * thread throws
 *
 *     java.lang.RuntimeException: Methods marked with @UiThread must be
 *     executed on the main thread. Current thread: UnityMain
 *
 * inside Unity's JNI call, which kills EVERY Unity -> Flutter message —
 * including outlet replies, so `flunity.invoke(...)` futures never resolve and
 * the bridge looks one-way. Hop onto the main looper before touching the
 * channel.
 */
class SendToFlutter {
    companion object {
        var methodChannel: MethodChannel? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun sendToFlutter(data: String) {
            val channel = methodChannel
            if (channel == null) {
                println("Couldn't send message from Unity to Flutter: method channel hasn't been initialised")
                return
            }
            if (Looper.myLooper() == Looper.getMainLooper()) {
                channel.invokeMethod(methodNameSendToFlutter, data)
            } else {
                mainHandler.post { channel.invokeMethod(methodNameSendToFlutter, data) }
            }
        }
    }
}
