package com.flunity.bridge.unity

import android.app.Activity
import androidx.lifecycle.LifecycleEventObserver

/**
 * The only place the plugin talks to [UnityPlayerSingleton] from. Everything
 * here resolves Unity classes, so callers check [UnityAvailability.present]
 * first — the plugin class itself must stay free of `com.unity3d` references
 * (see [UnityAvailability] for why).
 */
object UnityHost {
    fun attach(activity: Activity) {
        UnityPlayerSingleton.flutterActivity = activity
    }

    fun detach() {
        UnityPlayerSingleton.flutterActivity = null
    }

    fun destroy() {
        UnityPlayerSingleton.getInstance()?.destroy()
    }

    fun resumeObserver(): LifecycleEventObserver = ResumeUnityOnActivityResume()
}
