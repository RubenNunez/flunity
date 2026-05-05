using UnityEngine;

namespace Flunity {
    /// <summary>
    /// Bridge between Flutter (host) and Unity (guest). Place a single GameObject
    /// named "[FlunityBridge]" in your scene and attach this MonoBehaviour to it.
    /// Unity's SendMessage will dispatch inbound JSON to ReceiveFromFlutter.
    /// </summary>
    [DisallowMultipleComponent]
    public class FlunityBridgeBehaviour : MonoBehaviour {
        public static FlunityBridgeBehaviour Instance { get; private set; }

        void Awake() {
            if (Instance != null && Instance != this) {
                Destroy(this);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        // Called by the JS shim via unityInstance.SendMessage("[FlunityBridge]", "ReceiveFromFlutter", json)
        public void ReceiveFromFlutter(string json) {
            FlunityBridge.DispatchInbound(json);
        }
    }
}
