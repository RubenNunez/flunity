// Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import Foundation
import Flutter


// This is called by Unity script to pass messages from Unity to Flutter.
// DO NOT change @_cdecl: it is referenced in the Unity-side C# script that
// the flutter_native_bridge template ships under
// <unity project>/Assets/Plugins/iOS/FlunityBridgeNative.cs.
// @_cdecl allows C# (via DllImport "__Internal") to call this top-level function.
@_cdecl("FlunityBridge_sendToFlutter")
public func sendToFlutter(_ dataAsUnsafePointer: UnsafePointer<CChar>) {
    let data = String(cString: UnsafePointer<CChar>(dataAsUnsafePointer))
    SendToFlutter.sendToFlutter(data)
}


public class SendToFlutter {
    static var methodChannel: FlutterMethodChannel? = nil
    
    static func sendToFlutter(_ data: String) {
        if let methodChannel = methodChannel {
            methodChannel.invokeMethod(NativeConstants.methodNameSendToFlutter, arguments: data)
        }
        else {
            debugPrint("Couldn't send message from Unity to Flutter: method channel hasn't been initialised")
        }
    }
}
