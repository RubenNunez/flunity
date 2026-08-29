package com.flunity.bridge.unity

import android.app.Activity
import android.view.View
import android.view.ViewTreeObserver
import androidx.lifecycle.LifecycleEventObserver

/**
 * The only place the plugin talks to [UnityPlayerSingleton] from. Everything
 * here resolves Unity classes, so callers check [UnityAvailability.present]
 * first — the plugin class itself must stay free of `com.unity3d` references
 * (see [UnityAvailability] for why).
 */
object UnityHost {
    // Unity's own UnityPlayerActivity forwards onWindowFocusChanged(hasFocus) to
    // the player; a plain FlutterActivity never does, so Unity's focus state
    // would only ever be what we assert on attach. Unity ignores touches while
    // it believes the window is unfocused -- so background → foreground (or a
    // system dialog) could leave taps dead. A plugin cannot override Activity
    // methods, but the decor view's ViewTreeObserver sees every focus change.
    private var focusListener: ViewTreeObserver.OnWindowFocusChangeListener? = null
    private var focusHostView: View? = null

    fun attach(activity: Activity) {
        UnityPlayerSingleton.flutterActivity = activity
        val decor = activity.window?.decorView ?: return
        val listener = ViewTreeObserver.OnWindowFocusChangeListener { hasFocus ->
            UnityPlayerSingleton.getInstance()?.windowFocusChanged(hasFocus)
        }
        decor.viewTreeObserver.addOnWindowFocusChangeListener(listener)
        focusListener = listener
        focusHostView = decor
    }

    fun detach() {
        focusListener?.let { l -> focusHostView?.viewTreeObserver?.removeOnWindowFocusChangeListener(l) }
        focusListener = null
        focusHostView = null
        UnityPlayerSingleton.flutterActivity = null
    }

    fun destroy() {
        UnityPlayerSingleton.getInstance()?.destroy()
    }

    fun resumeObserver(): LifecycleEventObserver = ResumeUnityOnActivityResume()
}
