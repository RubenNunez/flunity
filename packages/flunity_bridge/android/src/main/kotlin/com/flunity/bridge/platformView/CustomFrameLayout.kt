// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.platformView

import android.view.InputDevice
import android.view.MotionEvent
import android.content.Context
import android.widget.FrameLayout
import io.flutter.Log
import android.view.View
import com.flunity.bridge.constants.NativeConstants.Companion.logTag
import com.flunity.bridge.unity.UnityPlayerSingleton

// Since Unity 6000 the UnityPlayer class no longer impements Framelayout.
// Use a Custom Framelayout to override events that we used to override in UnityPLayerSingleton.kt.
public class CustomFrameLayout : FrameLayout  {

    constructor(context: Context) : super(context)

    // TODO: Is this still functional if not on UnityPLayer's own FrameLayout?
    override fun onWindowVisibilityChanged(visibility: Int) {
        Log.d(logTag, "CustomFrameLayout onWindowVisibilityChanged $visibility")

        if(visibility == View.VISIBLE) {
            // For some unknown reason, if window visibility changes quickly from View.VISIBLE
            // to View.GONE and back to View.VISIBLE, Unity UI appears to freeze.
            // This happens, for example, on orientation change, flutter hot reload, and
            // occasionally on widget rebuild if there is a significant change to the widget
            // tree (you can usually see this as a brief flicker of the widget).
            // The underlying UnityPlayer is still active and still responds to messages even
            // though it appears frozen, so it is purely a UI thing. Presumably a bug in Unity.
            // However using UnityPlayer to render in a View like this is not supported so
            // unlikely to be fixed by Unity
            // (see https://docs.unity3d.com/Manual/UnityasaLibrary-Android.html)
            // As a workaround, pause and resume the player unfreezes the UI
            Log.d(logTag, "UnityPlayerSingleton became visible, so pausing and resuming Unity")

            UnityPlayerSingleton.getInstance()?.pause();
            UnityPlayerSingleton.getInstance()?.resume();
           // pause()
           // resume()
        }

        super.onWindowVisibilityChanged(visibility)
    }

    // This is required for Unity's New Input System to receive touch events.
    //
    // Every event goes to Unity under ONE device id. The Input System makes a
    // Touchscreen per Android deviceId, and a single gesture can arrive under
    // two: with Hybrid composition Flutter re-dispatches the original
    // MotionEvent (the real deviceId) when it still has it, and synthesizes one
    // with deviceId 0 when it does not. Rewriting only the 0s split such a
    // gesture across two Touchscreens -- the DOWN on one, the UP on the other --
    // which leaves the first touch "in progress" forever: `primaryTouch` never
    // ends, `Pointer.press` never fires again, and every tap into Unity is dead
    // until the player is paused (seen in jellx, 2026-10-08).
    //
    // deviceId 0 itself is not an option: Flutter's synthesized events use it
    // (https://github.com/flutter/flutter/blob/34b454f42dd6f8721dfe43fc7de5d215705b5e52/packages/flutter/lib/src/services/platform_views.dart#L639)
    // and the Input System does not detect touches from it.
    //
    // The incoming event belongs to Flutter, so it is not recycled here.
    override fun dispatchTouchEvent(motionEvent: MotionEvent): Boolean {
        if (motionEvent.deviceId == unityTouchDeviceId) {
            motionEvent.source = InputDevice.SOURCE_TOUCHSCREEN
            return super.dispatchTouchEvent(motionEvent)
        }
        val modifiedEvent = motionEvent.copy(deviceId = unityTouchDeviceId, source = InputDevice.SOURCE_TOUCHSCREEN)
        return super.dispatchTouchEvent(modifiedEvent)
    }

    private companion object {
        const val unityTouchDeviceId = -1
    }

}