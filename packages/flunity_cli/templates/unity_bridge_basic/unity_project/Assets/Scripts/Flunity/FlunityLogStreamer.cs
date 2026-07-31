using System.Collections.Concurrent;
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
    ///
    /// Subscribes to the *threaded* callback so logs from worker threads
    /// (async outlets, UnityWebRequest and Job System callbacks) are not
    /// lost, but only ever hands them to the bridge from <c>Update</c>:
    /// <see cref="FlunityBridge.SendRaw"/> reaches JNI on Android and a
    /// Flutter MethodChannel on iOS, neither of which may be touched off the
    /// main thread.
    /// </summary>
    [DisallowMultipleComponent]
    public class FlunityLogStreamer : MonoBehaviour {
        // Bounded so a log storm from a worker thread can't grow the queue
        // without limit if Update is starved or the object is disabled.
        const int MaxQueuedPayloads = 512;

        readonly ConcurrentQueue<string> _pending = new ConcurrentQueue<string>();
        int _dropped;

        void OnEnable() { Application.logMessageReceivedThreaded += OnLog; }
        void OnDisable() { Application.logMessageReceivedThreaded -= OnLog; }

        void Update() {
            string payload;
            while (_pending.TryDequeue(out payload)) {
                FlunityBridge.SendRaw("flunity_log", payload);
            }

            int dropped = System.Threading.Interlocked.Exchange(ref _dropped, 0);
            if (dropped > 0) {
                FlunityBridge.SendRaw("flunity_log",
                    "{\"level\":\"warn\",\"message\":\"" +
                    FlunityJson.Escape($"[Flunity] dropped {dropped} log(s): forward queue full") +
                    "\"}");
            }
        }

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
              .Append("\",\"message\":\"").Append(FlunityJson.Escape(condition))
              .Append('"');
            if (includeStack && !string.IsNullOrEmpty(stackTrace)) {
                sb.Append(",\"stackTrace\":\"").Append(FlunityJson.Escape(stackTrace)).Append('"');
            }
            sb.Append('}');

            // Building the payload is thread-safe; delivering it is not.
            if (_pending.Count >= MaxQueuedPayloads) {
                System.Threading.Interlocked.Increment(ref _dropped);
                return;
            }
            _pending.Enqueue(sb.ToString());
        }

    }
}
