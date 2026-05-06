using System.Text;
using UnityEngine;

namespace Flunity {
    /// <summary>
    /// Forwards every Unity <see cref="Debug"/> log to Flutter as a
    /// <c>flunity_log</c> bridge message. Auto-attached by
    /// <see cref="FlunityBridgeBehaviour"/> alongside the outlet registry.
    /// Flutter consumes the stream in <c>FlunityLogStream</c>.
    ///
    /// Wire format:
    /// <code>
    /// { "type": "flunity_log",
    ///   "payload": {"level":"info|warn|error", "message":"...",
    ///               "stackTrace":"..."} }
    /// </code>
    /// Stack traces are forwarded only for warnings + errors to keep info
    /// logs cheap (no string allocs for trivial Debug.Log lines).
    /// </summary>
    [DisallowMultipleComponent]
    public class FlunityLogStreamer : MonoBehaviour {
        void OnEnable() { Application.logMessageReceivedThreaded += OnLog; }
        void OnDisable() { Application.logMessageReceivedThreaded -= OnLog; }

        void OnLog(string condition, string stackTrace, LogType type) {
            // No Flutter side in the Editor — forwarding `flunity_log` only
            // creates noise, and on platforms where SendRaw falls back to
            // Debug.Log (everywhere except Webgl / iOS / Android player
            // builds) it triggers a feedback loop: our SendRaw emits a
            // Debug.Log, which fires this callback, which sends again, ...
            if (Application.isEditor) return;

            // Defensive filter: never forward FlunityBridge's own internal
            // diagnostics. Currently this fires only for the "(no-op outside
            // WebGL/iOS/Android)" fallback, but a strict prefix match keeps
            // the streamer recursion-proof against future bridge-side logs.
            if (condition != null && condition.StartsWith("[FlunityBridge] ")) return;

            string level;
            bool includeStack;
            switch (type) {
                case LogType.Error:
                case LogType.Exception:
                case LogType.Assert:
                    level = "error"; includeStack = true; break;
                case LogType.Warning:
                    level = "warn"; includeStack = true; break;
                default:
                    level = "info"; includeStack = false; break;
            }
            var sb = new StringBuilder(condition.Length + 64);
            sb.Append("{\"level\":\"").Append(level)
              .Append("\",\"message\":\"").Append(EscapeJson(condition))
              .Append('"');
            if (includeStack && !string.IsNullOrEmpty(stackTrace)) {
                sb.Append(",\"stackTrace\":\"").Append(EscapeJson(stackTrace)).Append('"');
            }
            sb.Append('}');
            FlunityBridge.SendRaw("flunity_log", sb.ToString());
        }

        static string EscapeJson(string s) {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length + 8);
            foreach (var c in s) {
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
