using UnityEngine;

namespace Flunity {
    /// <summary>
    /// Sample handler that listens for `load_scene` messages from Flutter and
    /// emits a `scene_ready` reply once the scene is loaded. Plan C ships this
    /// as the default demo wiring; remove or replace in real apps.
    /// </summary>
    public class FlunityBridgeDemo : MonoBehaviour {
        void OnEnable() {
            FlunityBridge.OnMessage += HandleMessage;
        }

        void OnDisable() {
            FlunityBridge.OnMessage -= HandleMessage;
        }

        void HandleMessage(string type, string payloadJson) {
            if (type == "load_scene") {
                // Game code would call SceneManager.LoadScene here. We don't —
                // we just acknowledge so the Flutter side can complete the
                // round trip in the smoke test.
                FlunityBridge.SendRaw("scene_ready", "{}");
            }
        }
    }
}
