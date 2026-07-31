using System;
using UnityEngine;

#if UNITY_WEBGL && !UNITY_EDITOR
using System.Runtime.InteropServices;
#endif

#if UNITY_IOS && !UNITY_EDITOR
using System.Runtime.InteropServices;
#endif

namespace Flunity {
    /// <summary>
    /// Static API for game code. Subscribe to <see cref="OnMessage"/> for inbound
    /// messages, call <see cref="Send{T}"/> or <see cref="SendRaw"/> to talk back
    /// to Flutter. Outbound dispatch picks the right native bridge based on
    /// build target: WebGL JS shim, iOS @_cdecl, or Android AndroidJavaClass.
    /// </summary>
    public static class FlunityBridge {
        public static event Action<string, string> OnMessage;

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void FlunityPostMessage(string json);
#endif

#if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void FlunityBridge_sendToFlutter(string json);
#endif

        public static void Send<T>(string type, T payload) {
            string payloadJson = JsonUtility.ToJson(payload ?? default(T));
            SendRaw(type, payloadJson);
        }

        public static void SendRaw(string type, string payloadJson) {
            string envelope = "{\"type\":\"" + FlunityJson.Escape(type) + "\",\"payload\":" +
                              (string.IsNullOrEmpty(payloadJson) ? "{}" : payloadJson) + "}";
#if UNITY_WEBGL && !UNITY_EDITOR
            FlunityPostMessage(envelope);
#elif UNITY_IOS && !UNITY_EDITOR
            FlunityBridge_sendToFlutter(envelope);
#elif UNITY_ANDROID && !UNITY_EDITOR
            using (var sendToFlutter = new AndroidJavaClass("com.flunity.bridge.messaging.SendToFlutter")) {
                sendToFlutter.CallStatic("sendToFlutter", envelope);
            }
#else
            Debug.Log("[FlunityBridge] (no-op outside WebGL/iOS/Android) " + envelope);
#endif
        }

        internal static void DispatchInbound(string json) {
            string type = FlunityJson.GetString(json, "type");
            string payload = FlunityJson.GetObject(json, "payload") ?? "{}";

            if (type == "ping") {
                string nonce = FlunityJson.GetString(payload, "nonce") ?? "";
                SendRaw("pong", "{\"nonce\":\"" + FlunityJson.Escape(nonce) + "\"}");
            }

            OnMessage?.Invoke(type, payload);
        }

    }
}
