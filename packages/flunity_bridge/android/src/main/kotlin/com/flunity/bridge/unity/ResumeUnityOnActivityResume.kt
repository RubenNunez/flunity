// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.unity

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.flunity.bridge.constants.NativeConstants.Companion.logTag
import io.flutter.Log


// Sometimes (not always) when the Activity is resumed, Unity appears to be frozen.
// There must be something internal in UnityPlayer which does this?
// So, add a lifecycle observer so we can resume Unity.
class ResumeUnityOnActivityResume : LifecycleEventObserver {
    override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
        //Log.d(logTag, "Detected lifecycle change $event")

        if (event == Lifecycle.Event.ON_RESUME) {
            Log.d(logTag, "Activity resumed, resuming Unity")
            // For some reason, we need to pause first, and then resume. Not sure why.
            UnityPlayerSingleton.getInstance()?.pause()
            UnityPlayerSingleton.getInstance()?.resume()
        }
        // Nothing else pauses Unity when the app leaves the screen: embedded as a library it
        // gets no Activity callbacks of its own, so it kept running in the background --
        // audio included. ON_STOP rather than ON_PAUSE, so a visible but unfocused window
        // (split screen, a system dialog) keeps animating.
        else if (event == Lifecycle.Event.ON_STOP) {
            Log.d(logTag, "Activity stopped, pausing Unity")
            UnityPlayerSingleton.getInstance()?.pause()
        }
    }
}
