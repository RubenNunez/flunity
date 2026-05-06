// Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import Flutter

#if canImport(UnityFramework)
class SendToUnity {
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            switch call.method {
            case NativeConstants.methodNameSendToUnity:
                let gameObjectMethodNameData = call.arguments as! [String]
                if(UnityPlayerSingleton.isInitialised) {
                    UnityPlayerSingleton.getInstance().sendMessageToGO(
                        withName: gameObjectMethodNameData[0],
                        functionName: gameObjectMethodNameData[1],
                        message: gameObjectMethodNameData[2])
                    result(true)
                }
                else {
                    debugPrint("Dropped message to Unity: Unity is not loaded yet")
                    result(false)
                }
            case NativeConstants.methodNamePauseUnity:
                if(UnityPlayerSingleton.isInitialised) {
                    UnityPlayerSingleton.getInstance().pause(true)
                    result(true)
                }
                else {
                    debugPrint("Didn't pause Unity: Unity is not loaded yet")
                    result(false)
                }
            case NativeConstants.methodNameResumeUnity:
                if(UnityPlayerSingleton.isInitialised) {
                    UnityPlayerSingleton.getInstance().pause(false)
                    result(true)
                }
                else {
                    debugPrint("Didn't resume Unity: Unity is not loaded yet")
                    result(false)
                }
            default:
              result(FlutterMethodNotImplemented)
            }
    }
}
#else
class SendToUnity {
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case NativeConstants.methodNameSendToUnity,
             NativeConstants.methodNamePauseUnity,
             NativeConstants.methodNameResumeUnity:
            debugPrint("flunity_bridge iOS: native UnityFramework unavailable (WebGL-only mode).")
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
#endif
