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
            // Flat list of nodes, parent referenced by id. Avoids
            // JsonUtility's hard 10-level recursion cap (real scenes —
            // anything with nested prefabs — go deeper). Flutter
            // rebuilds the tree client-side from parentId.
            var flat = new List<SceneNodeFlat>();
            for (int i = 0; i < SceneManager.sceneCount; i++) {
                var scene = SceneManager.GetSceneAt(i);
                if (!scene.isLoaded) continue;
                foreach (var go in scene.GetRootGameObjects()) {
                    Walk(go, parentId: "", into: flat);
                }
            }
            return new SceneTree { nodes = flat.ToArray() };
        }

        void Walk(GameObject go, string parentId, List<SceneNodeFlat> into) {
            var componentNames = new List<string>();
            foreach (var c in go.GetComponents<Component>()) {
                if (c != null) componentNames.Add(c.GetType().Name);
            }
            into.Add(new SceneNodeFlat {
                id = go.GetInstanceID().ToString(),
                parentId = parentId,
                name = go.name,
                active = go.activeInHierarchy,
                components = componentNames.ToArray()
            });
            foreach (Transform child in go.transform) {
                Walk(child.gameObject, go.GetInstanceID().ToString(), into);
            }
        }

        [FlunityOutlet("Flunity.Scene.Inspect")]
        public InspectResult Inspect(InspectArgs args) {
            if (args == null || string.IsNullOrEmpty(args.id)) {
                return new InspectResult { found = false, error = "missing id" };
            }
            if (!int.TryParse(args.id, out int instanceId)) {
                return new InspectResult { found = false, error = "id must be an integer" };
            }

            // Find the GameObject by InstanceID. Unity 6 deprecated
            // `Resources.InstanceIDToObject(int)` in favour of
            // `Resources.EntityIdToObject(EntityId)`. We iterate via
            // FindObjectsOfTypeAll instead — runs once per inspect call,
            // so the O(N) cost is fine, and it's portable across all
            // Unity 6 patches without depending on the new EntityId type.
            GameObject obj = null;
            foreach (var go in Resources.FindObjectsOfTypeAll<GameObject>()) {
                if (go == null) continue;
                if (!go.scene.IsValid()) continue; // skip prefabs in assets
                if (go.GetInstanceID() == instanceId) {
                    obj = go;
                    break;
                }
            }
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

    /// <summary>
    /// Flat representation of the scene graph. Nodes know their parent
    /// by id; clients (e.g. the Flutter Inspector) rebuild the tree
    /// client-side. Avoids `JsonUtility.ToJson`'s hard 10-level recursion
    /// cap which would silently fail on any non-trivial scene.
    /// </summary>
    [System.Serializable]
    public class SceneTree {
        public SceneNodeFlat[] nodes;
    }

    [System.Serializable]
    public class SceneNodeFlat {
        /// Unity InstanceID as string. Pass to Flunity.Scene.Inspect.
        public string id;
        /// Parent's id, or empty string for scene-root GameObjects.
        public string parentId;
        public string name;
        public bool active;
        public string[] components;
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
