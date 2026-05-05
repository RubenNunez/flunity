// Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

//
//  UnityPlatformView.swift
//  flutter_embed_unity_ios
//
//  Created by James Allen on 30/08/2023.
//

import Foundation
import Flutter

class UnityPlatformView : NSObject, FlutterPlatformView {
    
    private let unityViewController: UIViewController
    
    init(_ unityViewController: UIViewController) {
        self.unityViewController = unityViewController
    }
    
    func view() -> UIView {
        return unityViewController.view
    }
}
