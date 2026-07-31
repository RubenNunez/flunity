using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;

namespace Flunity {
    /// <summary>
    /// Discovers `[FlunityOutlet]` methods at runtime and routes
    /// `outlet_call` / `outlet_find` messages from Flutter to them.
    /// Sits next to <see cref="FlunityBridgeBehaviour"/> on the
    /// `[FlunityBridge]` GameObject.
    ///
    /// Resolution order for an outlet call named `&lt;X&gt;.&lt;Y&gt;`:
    ///   1. Static method match: `&lt;X&gt;` is a static class with a
    ///      `[FlunityOutlet]` `&lt;Y&gt;` method.
    ///   2. Targeted instance: `target` was supplied; find the MonoBehaviour
    ///      whose `[FlunityIdentity]` (or InstanceID fallback) matches.
    ///   3. Singleton instance: exactly one MonoBehaviour of class `&lt;X&gt;`
    ///      exists with the method `&lt;Y&gt;`. Multiple → ambiguous error.
    ///   4. Miss → "no such outlet".
    /// </summary>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(FlunityBridgeBehaviour))]
    public class FlunityOutletRegistry : MonoBehaviour {
        readonly Dictionary<string, MethodInfo> _staticOutlets =
            new Dictionary<string, MethodInfo>();

        // Per-class index of instance-method outlets: outlet name → method.
        // Class membership is verified at dispatch time by walking
        // FindObjectsOfTypeAll, so the index doesn't go stale across scene loads.
        readonly Dictionary<Type, Dictionary<string, MethodInfo>> _instanceOutletsByType =
            new Dictionary<Type, Dictionary<string, MethodInfo>>();

        // Reverse index: outlet name → declaring type. Used for the miss
        // path (so a typo gets a "no such outlet" rather than silent drop).
        readonly Dictionary<string, Type> _instanceOutletDeclaringType =
            new Dictionary<string, Type>();

        // Captured at Awake on the Unity main thread. Async outlet
        // continuations are scheduled here so reply dispatch (and any
        // Unity / JNI calls inside it) stay on the main thread.
        TaskScheduler _mainThreadScheduler = TaskScheduler.Default;

        void Awake() {
            if (System.Threading.SynchronizationContext.Current != null) {
                _mainThreadScheduler = TaskScheduler.FromCurrentSynchronizationContext();
            }
            ScanAssemblies();
            FlunityBridge.OnMessage += HandleInbound;
        }

        void OnDestroy() {
            FlunityBridge.OnMessage -= HandleInbound;
        }

        void ScanAssemblies() {
            foreach (var asm in AppDomain.CurrentDomain.GetAssemblies()) {
                Type[] types;
                try { types = asm.GetTypes(); }
                catch (ReflectionTypeLoadException e) {
                    types = e.Types.Where(t => t != null).ToArray();
                }

                foreach (var type in types) {
                    if (type == null) continue;
                    foreach (var method in type.GetMethods(
                        BindingFlags.Public | BindingFlags.Static |
                        BindingFlags.Instance | BindingFlags.DeclaredOnly)) {
                        var attr = method.GetCustomAttribute<FlunityOutletAttribute>();
                        if (attr == null) continue;

                        string name = attr.Name ?? $"{type.Name}.{method.Name}";

                        if (method.IsStatic) {
                            if (_staticOutlets.ContainsKey(name)) {
                                Debug.LogError(
                                    $"[Flunity] duplicate static outlet '{name}' " +
                                    $"on {type.FullName}.{method.Name}");
                                continue;
                            }
                            _staticOutlets[name] = method;
                        } else {
                            if (!typeof(MonoBehaviour).IsAssignableFrom(type)) {
                                Debug.LogWarning(
                                    $"[Flunity] [FlunityOutlet] on instance method " +
                                    $"{type.FullName}.{method.Name} ignored — declaring " +
                                    $"type is not a MonoBehaviour.");
                                continue;
                            }
                            if (!_instanceOutletsByType.TryGetValue(type, out var byName)) {
                                byName = new Dictionary<string, MethodInfo>();
                                _instanceOutletsByType[type] = byName;
                            }
                            if (byName.ContainsKey(name) ||
                                (_instanceOutletDeclaringType.TryGetValue(name, out var existingType) &&
                                 existingType != type)) {
                                Debug.LogError(
                                    $"[Flunity] duplicate instance outlet '{name}' " +
                                    $"on {type.FullName}.{method.Name}");
                                continue;
                            }
                            byName[name] = method;
                            _instanceOutletDeclaringType[name] = type;
                        }
                    }
                }
            }
            Debug.Log(
                $"[Flunity] outlet registry: {_staticOutlets.Count} static, " +
                $"{_instanceOutletsByType.Sum(kv => kv.Value.Count)} instance.");
        }

        void HandleInbound(string type, string payloadJson) {
            switch (type) {
                case "outlet_call": HandleOutletCall(payloadJson); break;
                case "outlet_find": HandleOutletFind(payloadJson); break;
            }
        }

        // ---------- outlet_call ----------

        void HandleOutletCall(string payloadJson) {
            // `args` stays a raw sub-object string that we feed to
            // JsonUtility per-method-arg-type once the method is resolved.
            string name = FlunityJson.GetString(payloadJson, "name");
            string nonce = FlunityJson.GetString(payloadJson, "nonce");
            string target = FlunityJson.GetString(payloadJson, "target");
            string argsJson = FlunityJson.GetObject(payloadJson, "args");

            // Diagnostic: confirm receipt at the registry. If Flutter sends
            // an outlet_call and never sees this entry in the log sheet,
            // the call didn't reach Unity (bridge GameObject missing,
            // SendMessage routing broken, etc.).
            Debug.Log($"[Flunity] outlet_call rx: {name} target={target ?? "(none)"} nonce={nonce}");

            if (string.IsNullOrEmpty(name) || string.IsNullOrEmpty(nonce)) {
                Debug.LogError($"[Flunity] outlet_call missing name/nonce: {payloadJson}");
                return;
            }

            try {
                if (_staticOutlets.TryGetValue(name, out var staticMethod)) {
                    DispatchInvocation(name, nonce, staticMethod, null, argsJson);
                    return;
                }

                if (!_instanceOutletDeclaringType.TryGetValue(name, out var declaringType)) {
                    ReplyError(nonce, $"no such outlet '{name}'");
                    return;
                }

                var method = _instanceOutletsByType[declaringType][name];
                MonoBehaviour instance = ResolveInstance(declaringType, target);
                if (instance == null) {
                    if (string.IsNullOrEmpty(target)) {
                        var count = FindObjectsByType(declaringType).Length;
                        if (count == 0) {
                            ReplyError(nonce, $"no instance of {declaringType.Name} in any loaded scene");
                        } else {
                            ReplyError(nonce,
                                $"{name} is ambiguous: {count} instances of {declaringType.Name}; " +
                                $"pass `target:` (FlunityIdentity or InstanceID)");
                        }
                    } else {
                        ReplyError(nonce, $"no instance with target='{target}' for {declaringType.Name}");
                    }
                    return;
                }

                DispatchInvocation(name, nonce, method, instance, argsJson);
            } catch (Exception ex) {
                ReplyError(nonce, ex.Message);
            }
        }

        void DispatchInvocation(string name, string nonce, MethodInfo method,
                                object instance, string argsJson) {
            var paramInfos = method.GetParameters();
            object[] callArgs;
            if (paramInfos.Length == 0) {
                callArgs = Array.Empty<object>();
            } else if (paramInfos.Length == 1) {
                var paramType = paramInfos[0].ParameterType;
                object arg;
                try {
                    arg = string.IsNullOrEmpty(argsJson) || argsJson == "{}"
                        ? Activator.CreateInstance(paramType)
                        : JsonUtility.FromJson(argsJson, paramType);
                } catch (Exception e) {
                    ReplyError(nonce, $"could not deserialize args for '{name}': {e.Message}");
                    return;
                }
                callArgs = new object[] { arg };
            } else {
                ReplyError(nonce,
                    $"outlet '{name}' has {paramInfos.Length} parameters; " +
                    $"only 0 or 1 supported (single args object).");
                return;
            }

            object result;
            try {
                result = method.Invoke(instance, callArgs);
            } catch (TargetInvocationException tie) {
                ReplyError(nonce, tie.InnerException?.Message ?? tie.Message);
                return;
            } catch (Exception e) {
                ReplyError(nonce, e.Message);
                return;
            }

            // Async support: await Task / Task<T> before replying. Schedule
            // the continuation on the captured main-thread scheduler so
            // ReplyAfterTask + any Unity / JNI calls inside it stay on the
            // main thread.
            if (result is Task task) {
                task.ContinueWith(
                    t => ReplyAfterTask(nonce, name, t),
                    System.Threading.CancellationToken.None,
                    TaskContinuationOptions.None,
                    _mainThreadScheduler);
                return;
            }
            ReplyOk(nonce, result);
        }

        void ReplyAfterTask(string nonce, string name, Task t) {
            if (t.IsFaulted) {
                ReplyError(nonce, t.Exception?.GetBaseException().Message ?? "Task faulted");
                return;
            }
            if (t.IsCanceled) {
                ReplyError(nonce, "Task canceled");
                return;
            }
            // Task<T> exposes Result via the `Result` property reflectively.
            var resultProp = t.GetType().GetProperty("Result");
            object value = null;
            if (resultProp != null && resultProp.PropertyType != typeof(void) &&
                resultProp.PropertyType.Name != "VoidTaskResult") {
                value = resultProp.GetValue(t);
            }
            ReplyOk(nonce, value);
        }

        // ---------- outlet_find ----------

        void HandleOutletFind(string payloadJson) {
            string nonce = FlunityJson.GetString(payloadJson, "nonce");
            string component = FlunityJson.GetString(payloadJson, "component");
            if (string.IsNullOrEmpty(nonce) || string.IsNullOrEmpty(component)) {
                Debug.LogError($"[Flunity] outlet_find missing nonce/component: {payloadJson}");
                return;
            }

            // Find the type whose Name matches `component`, AND which has at
            // least one [FlunityOutlet] method (so we don't return arbitrary
            // MonoBehaviours that aren't outlet-aware).
            Type declaringType = null;
            foreach (var t in _instanceOutletsByType.Keys) {
                if (t.Name == component) { declaringType = t; break; }
            }
            if (declaringType == null) {
                ReplyFind(nonce, Array.Empty<MonoBehaviour>(), declaringType: null);
                return;
            }

            var instances = FindObjectsByType(declaringType);
            ReplyFind(nonce, instances, declaringType);
        }

        MonoBehaviour ResolveInstance(Type declaringType, string target) {
            var instances = FindObjectsByType(declaringType);
            if (instances.Length == 0) return null;
            if (string.IsNullOrEmpty(target)) {
                return instances.Length == 1 ? instances[0] : null;
            }
            foreach (var inst in instances) {
                if (IdentityFor(inst) == target) return inst;
            }
            return null;
        }

        MonoBehaviour[] FindObjectsByType(Type t) {
            // Includes inactive objects so Flutter can drive activation.
            return Resources.FindObjectsOfTypeAll(t)
                .OfType<MonoBehaviour>()
                .Where(o => o.gameObject.scene.IsValid()) // skip prefabs in assets
                .ToArray();
        }

        string IdentityFor(MonoBehaviour mb) {
            var type = mb.GetType();
            foreach (var f in type.GetFields(BindingFlags.Public | BindingFlags.Instance)) {
                if (f.GetCustomAttribute<FlunityIdentityAttribute>() != null &&
                    f.FieldType == typeof(string)) {
                    var v = f.GetValue(mb) as string;
                    if (!string.IsNullOrEmpty(v)) return v;
                }
            }
            return mb.GetInstanceID().ToString();
        }

        // ---------- Reply helpers ----------

        void ReplyOk(string nonce, object value) {
            string valueJson = SerializeReturn(value);
            string payload = "{\"nonce\":\"" + FlunityJson.Escape(nonce) +
                             "\",\"ok\":true,\"value\":" + valueJson + "}";
            FlunityBridge.SendRaw("outlet_reply", payload);
        }

        void ReplyError(string nonce, string error) {
            string payload = "{\"nonce\":\"" + FlunityJson.Escape(nonce) +
                             "\",\"ok\":false,\"value\":null,\"error\":\"" +
                             FlunityJson.Escape(error) + "\"}";
            FlunityBridge.SendRaw("outlet_reply", payload);
        }

        void ReplyFind(string nonce, MonoBehaviour[] instances, Type declaringType) {
            var sb = new StringBuilder();
            sb.Append("{\"nonce\":\"").Append(FlunityJson.Escape(nonce)).Append("\",\"components\":[");
            for (int i = 0; i < instances.Length; i++) {
                if (i > 0) sb.Append(',');
                var inst = instances[i];
                string id = IdentityFor(inst);
                string nm = declaringType?.Name ?? inst.GetType().Name;
                string path = ScenePathOf(inst.gameObject);
                sb.Append("{\"id\":\"").Append(FlunityJson.Escape(id))
                  .Append("\",\"name\":\"").Append(FlunityJson.Escape(nm))
                  .Append("\",\"path\":\"").Append(FlunityJson.Escape(path)).Append("\"}");
            }
            sb.Append("]}");
            FlunityBridge.SendRaw("outlet_find_reply", sb.ToString());
        }

        static string ScenePathOf(GameObject go) {
            var parts = new List<string>();
            for (var t = go.transform; t != null; t = t.parent) {
                parts.Add(t.name);
            }
            parts.Reverse();
            return string.Join("/", parts);
        }

        static string SerializeReturn(object value) {
            if (value == null) return "null";
            // FlunityRawJson is the escape hatch for outlets that need
            // dynamic / deeply-nested return shapes that JsonUtility's
            // [Serializable] reflection can't handle cleanly. The wrapper's
            // string is already JSON; insert verbatim.
            if (value is FlunityRawJson raw) return raw.json;
            if (value is string s) return "\"" + FlunityJson.Escape(s) + "\"";
            if (value is bool b) return b ? "true" : "false";
            // Floats go through FlunityJson.Number, which maps NaN/Infinity to
            // null. Emitting them bare makes the whole envelope undecodable,
            // so one bad division would strand the call instead of the value.
            if (value is float || value is double) {
                return FlunityJson.Number(Convert.ToDouble(value, CultureInfo.InvariantCulture));
            }
            if (value is int || value is long || value is short || value is byte) {
                return Convert.ToString(value, CultureInfo.InvariantCulture);
            }
            // Complex types: rely on Unity's JsonUtility (requires [Serializable]).
            // Hits a 10-level recursion cap and a layout cache that bites
            // when the shape changes — return FlunityRawJson from the
            // outlet to bypass both.
            try { return JsonUtility.ToJson(value); }
            catch { return "null"; }
        }

    }
}
