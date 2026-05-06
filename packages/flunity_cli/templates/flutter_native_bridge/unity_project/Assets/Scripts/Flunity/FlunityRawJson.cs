namespace Flunity {
    /// <summary>
    /// Marker for outlet return values that are already serialized JSON.
    /// The registry inserts the wrapped string verbatim into the
    /// `outlet_reply` payload's `value` field — no double-encoding via
    /// JsonUtility, no [Serializable] class layout cache, no
    /// 10-level depth limit.
    ///
    /// Use this when your outlet's return shape is too big or too
    /// dynamic for `[System.Serializable]` to handle cleanly:
    ///
    /// <code>
    /// [FlunityOutlet("App.Stats")]
    /// public FlunityRawJson Stats() {
    ///     var sb = new StringBuilder();
    ///     sb.Append("{\"hp\":100,\"name\":\"Bunny\"}");
    ///     return new FlunityRawJson(sb.ToString());
    /// }
    /// </code>
    /// </summary>
    public class FlunityRawJson {
        public readonly string json;
        public FlunityRawJson(string json) {
            this.json = string.IsNullOrEmpty(json) ? "null" : json;
        }
    }
}
