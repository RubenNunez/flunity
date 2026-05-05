// Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import Flutter
import Foundation
import UnityFramework

// This is a container view for Unity, providing functionality
// to attach and detach Unity as a subview
class UnityView : UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func attachUnity(_ unityPlayerSingleton: UnityFramework) {
        let unityRootView = unityPlayerSingleton.appController().rootView!
        unityRootView.frame = bounds
        unityRootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(unityRootView)
    }
    
    func detachUnity() {
        subviews.forEach { subview in
            subview.removeFromSuperview()
        }
    }
}
