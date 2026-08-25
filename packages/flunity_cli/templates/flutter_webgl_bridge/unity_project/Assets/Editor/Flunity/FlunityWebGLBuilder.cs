// New code (not vendored). Provides a Flunity > Build > WebGL menu item and
// a Flunity.Build.BuildWebGL batch-mode entry point parallel to the iOS /
// Android exporters borrowed from flutter_embed_unity.
//
// Unlike the iOS/Android exporters this is a plain `BuildPipeline.BuildPlayer`
// invocation — Unity's WebGL output is consumed directly by `flunity webgl
// serve` and `flunity bundle webgl`; no post-export transformation needed.

using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class FlunityWebGLBuilder
{
    [MenuItem("Flunity/Build/WebGL (Dev)")]
    public static void BuildWebGLFromMenu() => BuildWebGLInternal(development: true);

    [MenuItem("Flunity/Build/WebGL (Release)")]
    public static void BuildWebGLReleaseFromMenu() =>
        BuildWebGLInternal(development: false);

    /// <summary>
    /// Builds the project's enabled scenes for the WebGL platform.
    /// Output goes to `-exportPath` if passed on the Unity CLI, otherwise
    /// `&lt;projectRoot&gt;/Builds/webgl`.
    ///
    /// Invoked headless by `flunity build webgl` via:
    ///     unity -batchmode -projectPath ... -executeMethod FlunityWebGLBuilder.BuildWebGL -quit
    /// Must have zero parameters — Unity's -executeMethod rejects optional args.
    ///
    /// Development is the default (fast IL2CPP). Pass `-release` for an
    /// optimized player. Uncompressed output: Android WebView cannot load
    /// Unity's .br payloads.
    /// </summary>
    public static void BuildWebGL()
    {
        bool development = !HasCliFlag("-release");
        BuildWebGLInternal(development);
    }

    private static void BuildWebGLInternal(bool development)
    {
        string exportPath = GetCliArg("-exportPath");
        if (string.IsNullOrEmpty(exportPath))
        {
            exportPath = Path.Combine(
                Application.dataPath, "..", "Builds", "webgl");
        }

        string[] scenes = EditorBuildSettings.scenes
            .Where(s => s.enabled)
            .Select(s => s.path)
            .ToArray();

        if (scenes.Length == 0)
        {
            string msg = "No enabled scenes in Build Settings — " +
                "add at least one scene before building WebGL.";
            if (Application.isBatchMode) throw new Exception(msg);
            Debug.LogError(msg);
            return;
        }

        // Uncompressed: Android WebView cannot Brotli-decompress Unity's
        // .br payloads (eval of compressed framework.js throws SyntaxError).
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Disabled;

        PlayerSettings.SetIl2CppCompilerConfiguration(
            BuildTargetGroup.WebGL,
            development
                ? Il2CppCompilerConfiguration.Debug
                : Il2CppCompilerConfiguration.Release);
        PlayerSettings.SetManagedStrippingLevel(
            BuildTargetGroup.WebGL,
            development
                ? ManagedStrippingLevel.Minimal
                : ManagedStrippingLevel.High);

        if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.WebGL)
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(
                BuildTargetGroup.WebGL, BuildTarget.WebGL);
        }

        string kind = development ? "development" : "release";
        Debug.Log($"Flunity: building WebGL ({kind}) → {exportPath}");
        BuildPlayerOptions opts = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = exportPath,
            target = BuildTarget.WebGL,
            options = development ? BuildOptions.Development : BuildOptions.None,
        };
        BuildReport report = BuildPipeline.BuildPlayer(opts);

        if (report.summary.result != BuildResult.Succeeded)
        {
            string msg = "Flunity: WebGL build failed.";
            if (Application.isBatchMode) throw new Exception(msg);
            Debug.LogError(msg);
            return;
        }

        Debug.Log("Flunity: WebGL build succeeded.");
        if (Application.isBatchMode) EditorApplication.Exit(0);
    }

    private static string GetCliArg(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == name) return args[i + 1];
        }
        return null;
    }

    private static bool HasCliFlag(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == name) return true;
        }
        return false;
    }
}
