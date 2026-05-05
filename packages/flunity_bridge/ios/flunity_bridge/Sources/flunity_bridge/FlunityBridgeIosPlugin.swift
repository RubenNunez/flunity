// Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import Flutter
import UIKit

public class FlunityBridgeIosPlugin: NSObject, FlutterPlugin {
    
    private let sendToUnity = SendToUnity()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register the method call handler
        let channel = FlutterMethodChannel(
            name: NativeConstants.uniqueIdentifier,
            binaryMessenger: registrar.messenger())
        let instance = FlunityBridgeIosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Register channel with SendToFlutter so it can send messages back to Flutter
        SendToFlutter.methodChannel = channel
        
        // Register a view factory
        // On the Flutter side, when we create a PlatformView with our unique identifier:
        // UiKitView(
        //    viewType: Constants.uniqueViewIdentifier,
        // )
        // the UnityViewFactory will be invoked to create a UnityPlatformView:
        let platformViewFactory = UnityViewFactory(messenger: registrar.messenger())
        registrar.register(
            platformViewFactory,
            withId: NativeConstants.uniqueIdentifier,
            gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicyWaitUntilTouchesEnded)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        sendToUnity.handle(call, result: result)
    }
}
