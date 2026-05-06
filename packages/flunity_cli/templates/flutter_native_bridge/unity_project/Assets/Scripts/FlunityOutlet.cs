using System;

namespace Flunity {
    /// <summary>
    /// Marks a public method (instance or static) as callable from Flutter
    /// via `flunity.invoke`. The default outlet name is
    /// `<DeclaringClass>.<MethodName>`; pass an explicit string to override.
    ///
    /// The method must accept zero or one argument. If one, it must be a
    /// `[Serializable]` class that Unity's `JsonUtility` can deserialize.
    /// Return type may be void, T, Task, or Task&lt;T&gt; — return values
    /// (and Task results) are JSON-serialized and routed back to the awaiting
    /// Flutter Future.
    ///
    /// See packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart for
    /// the Flutter-side API.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
    public class FlunityOutletAttribute : Attribute {
        public FlunityOutletAttribute() { Name = null; }
        public FlunityOutletAttribute(string name) { Name = name; }

        /// <summary>Override for the auto-generated `Class.Method` name.</summary>
        public string Name { get; }
    }

    /// <summary>
    /// Optional companion to <see cref="FlunityOutletAttribute"/>: marks a
    /// public string field on a MonoBehaviour as the instance ID Flutter
    /// should pass via `flunity.invoke(..., target: id)` to disambiguate
    /// between multiple instances of the same component class.
    ///
    /// When unset (or no field is decorated), the registry falls back to
    /// Unity's `GetInstanceID()` formatted as a string.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field, AllowMultiple = false)]
    public class FlunityIdentityAttribute : Attribute {
    }
}
