using System.Reflection;
using System.Text;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Flunity {
    /// <summary>
    /// System outlets for live scene introspection from Flutter. Auto-attached
    /// by <see cref="FlunityBridgeBehaviour"/> alongside the registry + log
    /// streamer.
    ///
    /// Returns hand-rolled JSON via <see cref="FlunityRawJson"/> rather than
    /// `[System.Serializable]` types — Unity's JsonUtility caps recursion at
    /// 10 levels (real scenes go deeper) and its layout cache breaks the
    /// build when serialized class shapes change between Editor + player.
    /// Manual JSON sidesteps both.
    ///
    /// Outlets:
    /// <list type="bullet">
    ///   <item><c>Flunity.Scene.Tree()</c> — scene roots + their immediate
    ///   GameObjects only (one level deep). Each node carries
    ///   <c>{id, parentId, name, active, kind, childCount, components[]}</c>.
    ///   Children expand on demand via <c>Flunity.Scene.Children</c>.</item>
    ///   <item><c>Flunity.Scene.Children({parentId})</c> — direct children
    ///   of one GameObject, one level only.</item>
    ///   <item><c>Flunity.Scene.Inspect({id})</c> — one GameObject's
    ///   components + their public fields + the outlets they expose.</item>
    /// </list>
    /// </summary>
    [DisallowMultipleComponent]
    public class FlunitySceneInspector : MonoBehaviour {

        // Tree() returns ONLY the top-level scene roots (depth 1). Every
        // child fetch is one round-trip via Flunity.Scene.Children. Real
        // scenes routinely have thousands of nodes deeper down — sending
        // them all at once blows past the iOS MethodChannel's practical
        // payload size and times out. Lazy is faster and simpler.

        [FlunityOutlet("Flunity.Scene.Tree")]
        public FlunityRawJson Tree() {
            // Diagnostic on entry/exit — if Flutter sees a Tree timeout
            // without these landing in the log sheet, the registry
            // dispatched but the method hung; with them, the method
            // finished but the reply got lost on the wire (likely a
            // stale UnityFramework — iOS dyld doesn't reload .frameworks
            // on Flutter hot restart, so re-run `flunity bundle ios`
            // and reinstall).
            int sceneCount = SceneManager.sceneCount;
            Debug.Log($"[Flunity.Scene] Tree() begin (scenes={sceneCount})");
            var sb = new StringBuilder(2048);
            sb.Append("{\"nodes\":[");
            bool first = true;
            int rootCount = 0;
            for (int i = 0; i < sceneCount; i++) {
                var scene = SceneManager.GetSceneAt(i);
                if (!scene.isLoaded) continue;
                string sceneId = "scene:" + scene.name;
                WriteSceneNodeJson(sb, scene.name, sceneId, ref first);
                // Immediate children of the synthetic scene root: this
                // scene's root GameObjects. Anything deeper is fetched
                // on demand via Flunity.Scene.Children.
                foreach (var go in scene.GetRootGameObjects()) {
                    WriteNodeJson(sb, go, sceneId, ref first);
                    rootCount++;
                }
            }
            sb.Append("]}");
            Debug.Log($"[Flunity.Scene] Tree() end (roots={rootCount}, bytes={sb.Length})");
            return new FlunityRawJson(sb.ToString());
        }

        void WriteSceneNodeJson(StringBuilder sb, string sceneName, string sceneId, ref bool first) {
            if (!first) sb.Append(',');
            first = false;
            sb.Append('{')
              .Append("\"id\":\"").Append(EscapeJson(sceneId)).Append('"')
              .Append(",\"parentId\":\"\"")
              .Append(",\"name\":\"").Append(EscapeJson(sceneName)).Append('"')
              .Append(",\"active\":true")
              .Append(",\"kind\":\"scene\"")
              .Append(",\"components\":[]")
              .Append('}');
        }

        /// <summary>
        /// Emits one GameObject node — NO recursion into children. Children
        /// are fetched on demand via <see cref="Children"/>. The
        /// <c>childCount</c> field tells the Flutter side whether to render
        /// an expand chevron (childCount &gt; 0) and whether expansion
        /// requires a fetch.
        /// </summary>
        void WriteNodeJson(StringBuilder sb, GameObject go, string parentId, ref bool first) {
            if (!first) sb.Append(',');
            first = false;
            sb.Append('{')
              .Append("\"id\":\"").Append(go.GetInstanceID()).Append('"')
              .Append(",\"parentId\":\"").Append(EscapeJson(parentId)).Append('"')
              .Append(",\"name\":\"").Append(EscapeJson(go.name)).Append('"')
              .Append(",\"active\":").Append(go.activeInHierarchy ? "true" : "false")
              .Append(",\"kind\":\"go\"")
              .Append(",\"childCount\":").Append(go.transform.childCount)
              .Append(",\"components\":[");
            bool firstComp = true;
            foreach (var c in go.GetComponents<Component>()) {
                if (c == null) continue;
                if (!firstComp) sb.Append(',');
                firstComp = false;
                sb.Append('"').Append(EscapeJson(c.GetType().Name)).Append('"');
            }
            sb.Append("]}");
        }

        [FlunityOutlet("Flunity.Scene.Children")]
        public FlunityRawJson Children(ChildrenArgs args) {
            Debug.Log($"[Flunity.Scene] Children(parentId={args?.parentId})");
            if (args == null || string.IsNullOrEmpty(args.parentId)) {
                return new FlunityRawJson("{\"nodes\":[]}");
            }
            // Resolve parent by instance id. Same lookup as Inspect.
            GameObject parent = null;
            if (int.TryParse(args.parentId, out int parentIid)) {
                foreach (var go in Resources.FindObjectsOfTypeAll<GameObject>()) {
                    if (go == null || !go.scene.IsValid()) continue;
                    if (go.GetInstanceID() == parentIid) { parent = go; break; }
                }
            }
            if (parent == null) {
                return new FlunityRawJson("{\"nodes\":[]}");
            }
            var sb = new StringBuilder(2048);
            sb.Append("{\"nodes\":[");
            bool first = true;
            foreach (Transform child in parent.transform) {
                WriteNodeJson(sb, child.gameObject, args.parentId, ref first);
            }
            sb.Append("]}");
            return new FlunityRawJson(sb.ToString());
        }

        [FlunityOutlet("Flunity.Scene.Inspect")]
        public FlunityRawJson Inspect(InspectArgs args) {
            if (args == null || string.IsNullOrEmpty(args.id)) {
                return ErrorJson("missing id");
            }
            if (!int.TryParse(args.id, out int instanceId)) {
                return ErrorJson("id must be an integer");
            }
            // Resolve InstanceID by iterating all loaded GameObjects. O(N)
            // but fine — Inspect runs on demand from the inspector tab.
            // Avoids `Resources.InstanceIDToObject` (deprecated in Unity 6).
            GameObject obj = null;
            foreach (var go in Resources.FindObjectsOfTypeAll<GameObject>()) {
                if (go == null) continue;
                if (!go.scene.IsValid()) continue;
                if (go.GetInstanceID() == instanceId) {
                    obj = go;
                    break;
                }
            }
            if (obj == null) {
                return ErrorJson("no GameObject with that InstanceID in any loaded scene");
            }

            var sb = new StringBuilder(2048);
            sb.Append("{\"found\":true")
              .Append(",\"id\":\"").Append(obj.GetInstanceID()).Append('"')
              .Append(",\"name\":\"").Append(EscapeJson(obj.name)).Append('"')
              .Append(",\"path\":\"").Append(EscapeJson(ScenePathOf(obj))).Append('"')
              .Append(",\"active\":").Append(obj.activeInHierarchy ? "true" : "false")
              .Append(",\"components\":[");
            bool firstComp = true;
            foreach (var c in obj.GetComponents<Component>()) {
                if (c == null) continue;
                if (!firstComp) sb.Append(',');
                firstComp = false;
                WriteComponentJson(sb, c);
            }
            sb.Append("]}");
            return new FlunityRawJson(sb.ToString());
        }

        void WriteComponentJson(StringBuilder sb, Component c) {
            var type = c.GetType();
            sb.Append('{').Append("\"type\":\"").Append(EscapeJson(type.Name)).Append('"');
            sb.Append(",\"fields\":[");
            bool first = true;
            foreach (var f in type.GetFields(BindingFlags.Public | BindingFlags.Instance)) {
                if (!first) sb.Append(',');
                first = false;
                object val = null;
                try { val = f.GetValue(c); } catch { /* ignore unreadable */ }
                sb.Append('{')
                  .Append("\"name\":\"").Append(EscapeJson(f.Name)).Append('"')
                  .Append(",\"type\":\"").Append(EscapeJson(f.FieldType.Name)).Append('"')
                  .Append(",\"value\":\"").Append(EscapeJson(ToDisplayString(val))).Append('"')
                  .Append('}');
            }
            sb.Append("],\"outlets\":[");
            bool firstOutlet = true;
            foreach (var m in type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static)) {
                var attr = m.GetCustomAttribute<FlunityOutletAttribute>();
                if (attr == null) continue;
                if (!firstOutlet) sb.Append(',');
                firstOutlet = false;
                string outletName = attr.Name ?? $"{type.Name}.{m.Name}";
                sb.Append('"').Append(EscapeJson(outletName)).Append('"');
            }
            sb.Append("]}");
        }

        // ---------- helpers ----------

        FlunityRawJson ErrorJson(string message) {
            var sb = new StringBuilder();
            sb.Append("{\"found\":false,\"error\":\"").Append(EscapeJson(message)).Append("\"}");
            return new FlunityRawJson(sb.ToString());
        }

        static string ScenePathOf(GameObject go) {
            var sb = new StringBuilder();
            for (var t = go.transform; t != null; t = t.parent) {
                if (sb.Length > 0) sb.Insert(0, '/');
                sb.Insert(0, t.name);
            }
            return sb.ToString();
        }

        static string ToDisplayString(object v) {
            if (v == null) return "null";
            if (v is string s) return s;
            return v.ToString();
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

    /// <summary>Args for <see cref="FlunitySceneInspector.Inspect"/>.</summary>
    [System.Serializable]
    public class InspectArgs {
        public string id;
    }

    /// <summary>
    /// Args for <see cref="FlunitySceneInspector.Children"/>. Returns
    /// the GameObjects that are direct children of the GameObject with
    /// instance id <c>parentId</c> — one level only. Deeper expansion
    /// is the caller's job (one Children() call per expand click).
    /// </summary>
    [System.Serializable]
    public class ChildrenArgs {
        public string parentId;
    }
}
