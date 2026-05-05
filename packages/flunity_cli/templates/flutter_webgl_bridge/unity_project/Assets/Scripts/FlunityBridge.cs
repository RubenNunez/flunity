using System;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_WEBGL && !UNITY_EDITOR
using System.Runtime.InteropServices;
#endif

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

    /// <summary>
    /// Static API for game code. Subscribe to <see cref="OnMessage"/> for inbound
    /// messages, call <see cref="Send{T}"/> or <see cref="SendRaw"/> to talk back
    /// to Flutter. WebGL-only — no-ops in the editor and on other platforms.
    /// </summary>
    public static class FlunityBridge {
        /// <summary>Raised for every inbound message. (type, payloadJson).</summary>
        public static event Action<string, string> OnMessage;

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void FlunityPostMessage(string json);
#endif

        /// <summary>
        /// Sends a typed message to Flutter. Payload is JSON-serialized via Unity's
        /// JsonUtility (so the type must be marked [Serializable] with public fields).
        /// </summary>
        public static void Send<T>(string type, T payload) {
            string payloadJson = JsonUtility.ToJson(payload ?? default(T));
            SendRaw(type, payloadJson);
        }

        /// <summary>
        /// Sends a message with an already-serialized payload string.
        /// </summary>
        public static void SendRaw(string type, string payloadJson) {
            string envelope = "{\"type\":\"" + EscapeJson(type) + "\",\"payload\":" +
                              (string.IsNullOrEmpty(payloadJson) ? "{}" : payloadJson) + "}";
#if UNITY_WEBGL && !UNITY_EDITOR
            FlunityPostMessage(envelope);
#else
            Debug.Log("[FlunityBridge] (no-op outside WebGL) " + envelope);
#endif
        }

        // Called by FlunityBridgeBehaviour.ReceiveFromFlutter.
        internal static void DispatchInbound(string json) {
            // Cheap envelope parse to extract `type`. Game code can re-parse the
            // payload itself with JsonUtility.FromJson when it knows the shape.
            string type = ExtractStringField(json, "type");
            string payload = ExtractObjectField(json, "payload") ?? "{}";

            // Auto-respond to Ping with matching-nonce Pong (smoke test).
            if (type == "ping") {
                string nonce = ExtractStringField(payload, "nonce") ?? "";
                SendRaw("pong", "{\"nonce\":\"" + EscapeJson(nonce) + "\"}");
            }

            OnMessage?.Invoke(type, payload);
        }

        // ---- Mini JSON helpers ----
        // Deliberately tiny — game code does its own deserialization for richer
        // payloads. These exist only so the bridge can introspect the envelope.

        static string ExtractStringField(string json, string field) {
            string key = "\"" + field + "\"";
            int idx = json.IndexOf(key, StringComparison.Ordinal);
            if (idx < 0) return null;
            int colon = json.IndexOf(':', idx + key.Length);
            if (colon < 0) return null;
            int quote = json.IndexOf('"', colon + 1);
            if (quote < 0) return null;
            int end = quote + 1;
            var sb = new System.Text.StringBuilder();
            while (end < json.Length) {
                char c = json[end];
                if (c == '\\' && end + 1 < json.Length) { sb.Append(json[end + 1]); end += 2; continue; }
                if (c == '"') break;
                sb.Append(c);
                end += 1;
            }
            return sb.ToString();
        }

        static string ExtractObjectField(string json, string field) {
            string key = "\"" + field + "\"";
            int idx = json.IndexOf(key, StringComparison.Ordinal);
            if (idx < 0) return null;
            int colon = json.IndexOf(':', idx + key.Length);
            if (colon < 0) return null;
            int braceStart = json.IndexOf('{', colon);
            if (braceStart < 0) return null;
            int depth = 0;
            for (int i = braceStart; i < json.Length; i++) {
                char c = json[i];
                if (c == '{') depth++;
                else if (c == '}') { depth--; if (depth == 0) return json.Substring(braceStart, i - braceStart + 1); }
            }
            return null;
        }

        static string EscapeJson(string s) {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new System.Text.StringBuilder(s.Length + 8);
            foreach (char c in s) {
                switch (c) {
                    case '\\': sb.Append("\\\\"); break;
                    case '"':  sb.Append("\\\""); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c);
                        else sb.Append(c);
                        break;
                }
            }
            return sb.ToString();
        }
    }
}
