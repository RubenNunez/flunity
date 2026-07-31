using System.Globalization;
using System.Text;

namespace Flunity {
    /// <summary>
    /// The bridge's minimal JSON reader/writer.
    ///
    /// Unity's <c>JsonUtility</c> can only bind a whole object to a typed
    /// class, but the bridge needs to peek at a couple of envelope fields
    /// before it knows which type to bind — hence these helpers.
    ///
    /// Lookups are scoped to top-level keys. A substring search is not good
    /// enough: <c>outlet_call</c> omits <c>target</c> when it is null and
    /// always emits <c>args</c> last, so a naive search for "target" finds the
    /// caller's own argument and the outlet resolves against the wrong thing.
    ///
    /// Deliberately free of UnityEngine references so it can be compiled and
    /// tested outside the editor — see csharp/Flunity.Json.Tests.
    /// </summary>
    public static class FlunityJson {
        /// <summary>
        /// Value of the top-level string field, or null if it is absent, is
        /// not a string, or the input is not a JSON object.
        /// </summary>
        public static string GetString(string json, string field) {
            string raw = FindRawValue(json, field);
            if (string.IsNullOrEmpty(raw) || raw[0] != '"') return null;
            return Unescape(raw, 1, raw.Length - 1);
        }

        /// <summary>
        /// Raw text of the top-level object field, braces included, or null if
        /// it is absent or is not an object. Hand back to JsonUtility.
        /// </summary>
        public static string GetObject(string json, string field) {
            string raw = FindRawValue(json, field);
            if (string.IsNullOrEmpty(raw) || raw[0] != '{') return null;
            return raw;
        }

        /// <summary>Escapes a string for embedding in a JSON string literal (no surrounding quotes).</summary>
        public static string Escape(string s) {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length + 8);
            for (int i = 0; i < s.Length; i++) {
                char c = s[i];
                switch (c) {
                    case '\\': sb.Append("\\\\"); break;
                    case '"': sb.Append("\\\""); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    default:
                        if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                        else sb.Append(c);
                        break;
                }
            }
            return sb.ToString();
        }

        /// <summary>
        /// Formats a double as a JSON number. JSON has no NaN or Infinity
        /// literal, so those become <c>null</c> — emitting them bare would
        /// produce an envelope the Flutter side cannot decode at all, which
        /// strands the whole call rather than just this one value.
        /// </summary>
        public static string Number(double value) {
            if (double.IsNaN(value) || double.IsInfinity(value)) return "null";
            return value.ToString("R", CultureInfo.InvariantCulture);
        }

        // ---- Internals ----

        /// <summary>
        /// Raw text of the value bound to a top-level key, or null. Nested
        /// occurrences of the key are skipped over, never matched.
        /// </summary>
        static string FindRawValue(string json, string field) {
            if (string.IsNullOrEmpty(json) || field == null) return null;

            int i = SkipWhitespace(json, 0);
            if (i >= json.Length || json[i] != '{') return null;
            i++;

            while (true) {
                i = SkipWhitespace(json, i);
                if (i >= json.Length || json[i] == '}') return null;
                if (json[i] != '"') return null;

                int keyEnd = SkipString(json, i);
                if (keyEnd < 0) return null;
                string key = Unescape(json, i + 1, keyEnd - 1);

                i = SkipWhitespace(json, keyEnd);
                if (i >= json.Length || json[i] != ':') return null;

                int valueStart = SkipWhitespace(json, i + 1);
                if (valueStart >= json.Length) return null;
                int valueEnd = SkipValue(json, valueStart);
                if (valueEnd < 0) return null;

                if (key == field) return json.Substring(valueStart, valueEnd - valueStart);

                i = SkipWhitespace(json, valueEnd);
                if (i >= json.Length) return null;
                if (json[i] == ',') { i++; continue; }
                return null;
            }
        }

        static int SkipWhitespace(string s, int i) {
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
            return i;
        }

        /// <summary>Index just past the closing quote of the string starting at <paramref name="i"/>, or -1.</summary>
        static int SkipString(string s, int i) {
            i++; // opening quote
            while (i < s.Length) {
                char c = s[i];
                if (c == '\\') { i += 2; continue; }
                if (c == '"') return i + 1;
                i++;
            }
            return -1;
        }

        /// <summary>Index just past the value starting at <paramref name="i"/>, or -1.</summary>
        static int SkipValue(string s, int i) {
            char c = s[i];
            if (c == '"') return SkipString(s, i);
            if (c == '{' || c == '[') return SkipContainer(s, i);

            // Literal: number, true, false, null.
            int start = i;
            while (i < s.Length && s[i] != ',' && s[i] != '}' && s[i] != ']') i++;
            while (i > start && (s[i - 1] == ' ' || s[i - 1] == '\t' || s[i - 1] == '\n' || s[i - 1] == '\r')) i--;
            return i > start ? i : -1;
        }

        static int SkipContainer(string s, int i) {
            char open = s[i];
            char close = open == '{' ? '}' : ']';
            int depth = 0;
            while (i < s.Length) {
                char c = s[i];
                if (c == '"') {
                    int next = SkipString(s, i);
                    if (next < 0) return -1;
                    i = next;
                    continue;
                }
                if (c == open) depth++;
                else if (c == close) {
                    depth--;
                    if (depth == 0) return i + 1;
                }
                i++;
            }
            return -1;
        }

        /// <summary>Decodes JSON string-literal escapes between two indices (quotes excluded).</summary>
        static string Unescape(string s, int start, int end) {
            var sb = new StringBuilder(end - start);
            int i = start;
            while (i < end) {
                char c = s[i];
                if (c != '\\' || i + 1 >= end) { sb.Append(c); i++; continue; }

                char esc = s[i + 1];
                i += 2;
                switch (esc) {
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case '"': sb.Append('"'); break;
                    case '\\': sb.Append('\\'); break;
                    case '/': sb.Append('/'); break;
                    case 'u':
                        if (i + 4 <= end) {
                            int code;
                            if (int.TryParse(s.Substring(i, 4), NumberStyles.HexNumber,
                                             CultureInfo.InvariantCulture, out code)) {
                                sb.Append((char)code);
                                i += 4;
                                break;
                            }
                        }
                        sb.Append(esc);
                        break;
                    default:
                        sb.Append(esc);
                        break;
                }
            }
            return sb.ToString();
        }
    }
}
