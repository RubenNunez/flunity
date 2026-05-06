using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Flunity {
    /// <summary>
    /// System outlets for live scene introspection from Flutter. Auto-attached
    /// by <see cref="FlunityBridgeBehaviour"/> alongside the registry + log
    /// streamer.
    ///
    /// Exposes:
    /// <list type="bullet">
    ///   <item><c>Flunity.Scene.Tree()</c> — full scene graph as a tree of
    ///   <see cref="SceneNode"/>.</item>
    ///   <item><c>Flunity.Scene.Inspect({id})</c> — one GameObject's
    ///   components + their public fields + the outlets they expose.</item>
    /// </list>
    ///
    /// Used by the Flutter-side Inspector tab. Cheap to call — no per-frame
    /// work, just on-demand reflection over <c>SceneManager</c>.
    /// </summary>
    [DisallowMultipleComponent]
    public class FlunitySceneInspector : MonoBehaviour {

        [FlunityOutlet("Flunity.Scene.Tree")]
        public SceneTree Tree() {
            var roots = new List<SceneNode>();
            for (int i = 0; i < SceneManager.sceneCount; i++) {
                var scene = SceneManager.GetSceneAt(i);
                if (!scene.isLoaded) continue;
                foreach (var go in scene.GetRootGameObjects()) {
                    roots.Add(BuildNode(go));
                }
            }
            return new SceneTree { roots = roots.ToArray() };
        }

        [FlunityOutlet("Flunity.Scene.Inspect")]
        public InspectResult Inspect(InspectArgs args) {
            if (args == null || string.IsNullOrEmpty(args.id)) {
                return new InspectResult { found = false, error = "missing id" };
            }
            if (!int.TryParse(args.id, out int instanceId)) {
                return new InspectResult { found = false, error = "id must be an integer" };
            }
            var obj = Resources.InstanceIDToObject(instanceId) as GameObject;
            if (obj == null) {
                return new InspectResult { found = false, error = "no GameObject with that InstanceID in any loaded scene" };
            }

            var components = new List<ComponentInfo>();
            foreach (var c in obj.GetComponents<Component>()) {
                if (c == null) continue;
                var type = c.GetType();
                var fields = new List<FieldEntry>();
                foreach (var f in type.GetFields(BindingFlags.Public | BindingFlags.Instance)) {
                    object val = null;
                    try { val = f.GetValue(c); } catch { /* ignore unreadable */ }
                    fields.Add(new FieldEntry {
                        name = f.Name,
                        type = f.FieldType.Name,
                        value = ToDisplayString(val)
                    });
                }
                var outlets = new List<string>();
                foreach (var m in type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static)) {
                    var attr = m.GetCustomAttribute<FlunityOutletAttribute>();
                    if (attr != null) outlets.Add(attr.Name ?? $"{type.Name}.{m.Name}");
                }
                components.Add(new ComponentInfo {
                    type = type.Name,
                    fields = fields.ToArray(),
                    outlets = outlets.ToArray()
                });
            }

            return new InspectResult {
                found = true,
                id = instanceId.ToString(),
                name = obj.name,
                path = ScenePathOf(obj),
                active = obj.activeInHierarchy,
                components = components.ToArray()
            };
        }

        // ---------- helpers ----------

        SceneNode BuildNode(GameObject go) {
            var componentNames = new List<string>();
            foreach (var c in go.GetComponents<Component>()) {
                if (c != null) componentNames.Add(c.GetType().Name);
            }
            var children = new List<SceneNode>();
            foreach (Transform child in go.transform) {
                children.Add(BuildNode(child.gameObject));
            }
            return new SceneNode {
                id = go.GetInstanceID().ToString(),
                name = go.name,
                active = go.activeInHierarchy,
                components = componentNames.ToArray(),
                children = children.ToArray()
            };
        }

        static string ScenePathOf(GameObject go) {
            var parts = new List<string>();
            for (var t = go.transform; t != null; t = t.parent) {
                parts.Add(t.name);
            }
            parts.Reverse();
            return string.Join("/", parts);
        }

        static string ToDisplayString(object v) {
            if (v == null) return "null";
            if (v is string s) return s;
            // Unity types' ToString() is usually adequate (e.g. Vector3 → "(0.0, 1.0, 0.0)").
            return v.ToString();
        }
    }

    [System.Serializable]
    public class SceneTree {
        public SceneNode[] roots;
    }

    [System.Serializable]
    public class SceneNode {
        public string id;
        public string name;
        public bool active;
        public string[] components;
        public SceneNode[] children;
    }

    [System.Serializable]
    public class InspectArgs {
        public string id;
    }

    [System.Serializable]
    public class InspectResult {
        public bool found;
        public string id;
        public string name;
        public string path;
        public bool active;
        public ComponentInfo[] components;
        public string error;
    }

    [System.Serializable]
    public class ComponentInfo {
        public string type;
        public FieldEntry[] fields;
        public string[] outlets;
    }

    [System.Serializable]
    public class FieldEntry {
        public string name;
        public string type;
        public string value;
    }
}
