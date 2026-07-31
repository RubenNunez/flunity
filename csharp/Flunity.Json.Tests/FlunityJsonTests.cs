using Flunity;
using Xunit;

namespace Flunity.Json.Tests {
    public class GetStringTests {
        [Fact]
        public void ReadsATopLevelStringField() {
            var json = "{\"name\":\"Creature.Feed\",\"nonce\":\"7\"}";
            Assert.Equal("Creature.Feed", FlunityJson.GetString(json, "name"));
            Assert.Equal("7", FlunityJson.GetString(json, "nonce"));
        }

        [Fact]
        public void ReturnsNullForAMissingField() {
            Assert.Null(FlunityJson.GetString("{\"name\":\"X\"}", "target"));
        }

        // The bug this class exists to fix: outlet_call omits `target` when it
        // is null and always emits `args` last, so a naive substring search
        // finds the caller's own `args.target` and Unity resolves against it.
        [Fact]
        public void IgnoresAMatchingKeyNestedInsideAnotherObject() {
            var json = "{\"name\":\"Turret.Aim\",\"nonce\":\"1\","
                     + "\"args\":{\"target\":\"enemy_1\"}}";
            Assert.Null(FlunityJson.GetString(json, "target"));
        }

        [Fact]
        public void PrefersTheTopLevelKeyOverANestedOneWithTheSameName() {
            var json = "{\"name\":\"Turret.Aim\",\"target\":\"turret_a\","
                     + "\"args\":{\"target\":\"enemy_1\"}}";
            Assert.Equal("turret_a", FlunityJson.GetString(json, "target"));
        }

        [Fact]
        public void IgnoresAMatchingKeyNestedInsideAnArray() {
            var json = "{\"name\":\"X\",\"args\":{\"items\":[{\"target\":\"a\"}]}}";
            Assert.Null(FlunityJson.GetString(json, "target"));
        }

        [Fact]
        public void IgnoresAKeyNameThatOnlyAppearsAsAStringValue() {
            var json = "{\"name\":\"target\",\"args\":{}}";
            Assert.Null(FlunityJson.GetString(json, "target"));
        }

        [Fact]
        public void ReturnsNullWhenTheFieldIsNotAString() {
            var json = "{\"name\":\"X\",\"count\":3,\"nested\":{},\"flag\":true}";
            Assert.Null(FlunityJson.GetString(json, "count"));
            Assert.Null(FlunityJson.GetString(json, "nested"));
            Assert.Null(FlunityJson.GetString(json, "flag"));
        }

        [Fact]
        public void ReadsAnExplicitJsonNullAsNull() {
            Assert.Null(FlunityJson.GetString("{\"target\":null,\"name\":\"X\"}", "target"));
        }

        [Fact]
        public void ToleratesWhitespaceAroundStructuralCharacters() {
            var json = "{ \"name\" : \"X\" , \"target\" : \"t\" }";
            Assert.Equal("t", FlunityJson.GetString(json, "target"));
        }

        [Fact]
        public void ReturnsNullForMalformedInput() {
            Assert.Null(FlunityJson.GetString("not json", "name"));
            Assert.Null(FlunityJson.GetString("", "name"));
            Assert.Null(FlunityJson.GetString(null, "name"));
            Assert.Null(FlunityJson.GetString("{\"name\":", "name"));
        }
    }

    public class UnescapeTests {
        [Fact]
        public void DecodesTheTwoCharacterEscapes() {
            var json = "{\"v\":\"a\\nb\\tc\\r\\\\d\\\"e\\/f\"}";
            Assert.Equal("a\nb\tc\r\\d\"e/f", FlunityJson.GetString(json, "v"));
        }

        [Fact]
        public void DecodesBackspaceAndFormFeed() {
            Assert.Equal("a\bb\fc", FlunityJson.GetString("{\"v\":\"a\\bb\\fc\"}", "v"));
        }

        [Fact]
        public void DecodesUnicodeEscapes() {
            Assert.Equal("café", FlunityJson.GetString("{\"v\":\"caf\\u00e9\"}", "v"));
        }

        [Fact]
        public void DecodesSurrogatePairsFromUnicodeEscapes() {
            Assert.Equal("\U0001F600", FlunityJson.GetString("{\"v\":\"\\ud83d\\ude00\"}", "v"));
        }

        [Fact]
        public void KeepsAnEscapedQuoteFromEndingTheValueEarly() {
            var json = "{\"v\":\"say \\\"hi\\\"\",\"after\":\"ok\"}";
            Assert.Equal("say \"hi\"", FlunityJson.GetString(json, "v"));
            Assert.Equal("ok", FlunityJson.GetString(json, "after"));
        }

        [Fact]
        public void KeepsATrailingEscapedBackslashFromSwallowingTheClosingQuote() {
            var json = "{\"v\":\"path\\\\\",\"after\":\"ok\"}";
            Assert.Equal("path\\", FlunityJson.GetString(json, "v"));
            Assert.Equal("ok", FlunityJson.GetString(json, "after"));
        }
    }

    public class GetObjectTests {
        [Fact]
        public void ReturnsTheRawTextOfANestedObject() {
            var json = "{\"name\":\"X\",\"args\":{\"a\":1,\"b\":{\"c\":2}}}";
            Assert.Equal("{\"a\":1,\"b\":{\"c\":2}}", FlunityJson.GetObject(json, "args"));
        }

        [Fact]
        public void IsNotConfusedByBracesInsideStringValues() {
            var json = "{\"args\":{\"text\":\"a } b { c\"},\"after\":\"ok\"}";
            Assert.Equal("{\"text\":\"a } b { c\"}", FlunityJson.GetObject(json, "args"));
        }

        [Fact]
        public void IsNotConfusedByEscapedQuotesInsideStringValues() {
            var json = "{\"args\":{\"text\":\"he said \\\"}\\\"\"}}";
            Assert.Equal("{\"text\":\"he said \\\"}\\\"\"}", FlunityJson.GetObject(json, "args"));
        }

        [Fact]
        public void ReturnsNullWhenTheFieldIsAbsentOrNotAnObject() {
            Assert.Null(FlunityJson.GetObject("{\"a\":1}", "args"));
            Assert.Null(FlunityJson.GetObject("{\"args\":\"str\"}", "args"));
            Assert.Null(FlunityJson.GetObject("{\"args\":null}", "args"));
        }

        [Fact]
        public void IgnoresANestedKeyWithTheSameName() {
            var json = "{\"payload\":{\"args\":{\"inner\":1}}}";
            Assert.Null(FlunityJson.GetObject(json, "args"));
        }
    }

    public class EscapeTests {
        [Fact]
        public void EscapesTheCharactersThatWouldBreakAStringLiteral() {
            Assert.Equal("a\\\\b\\\"c\\nd\\re\\tf", FlunityJson.Escape("a\\b\"c\nd\re\tf"));
        }

        [Fact]
        public void EscapesOtherControlCharactersAsUnicode() {
            Assert.Equal("\\u0000\\u001f", FlunityJson.Escape("\u0000\u001f"));
        }

        [Fact]
        public void LeavesOrdinaryTextUntouched() {
            Assert.Equal("café \U0001F600", FlunityJson.Escape("café \U0001F600"));
        }

        [Fact]
        public void TreatsNullAsEmpty() {
            Assert.Equal("", FlunityJson.Escape(null));
        }

        [Fact]
        public void RoundTripsThroughGetString() {
            var value = "quotes \" backslash \\ newline \n tab \t brace } unicode café";
            var json = "{\"v\":\"" + FlunityJson.Escape(value) + "\"}";
            Assert.Equal(value, FlunityJson.GetString(json, "v"));
        }
    }

    public class NumberTests {
        [Fact]
        public void FormatsFiniteValuesWithAnInvariantDecimalPoint() {
            Assert.Equal("1.5", FlunityJson.Number(1.5));
            Assert.Equal("-0.25", FlunityJson.Number(-0.25));
            Assert.Equal("3", FlunityJson.Number(3.0));
        }

        // JSON has no NaN/Infinity literals. Emitting them bare produces an
        // envelope Flutter cannot decode, which strands the pending call.
        [Fact]
        public void EmitsNullForValuesJsonCannotRepresent() {
            Assert.Equal("null", FlunityJson.Number(double.NaN));
            Assert.Equal("null", FlunityJson.Number(double.PositiveInfinity));
            Assert.Equal("null", FlunityJson.Number(double.NegativeInfinity));
        }

        [Fact]
        public void RoundTripsPrecisionSensitiveValues() {
            Assert.Equal(0.1 + 0.2, double.Parse(
                FlunityJson.Number(0.1 + 0.2),
                System.Globalization.CultureInfo.InvariantCulture));
        }
    }
}
