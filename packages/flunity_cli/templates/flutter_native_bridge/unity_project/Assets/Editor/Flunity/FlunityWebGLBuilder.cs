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
    [MenuItem("Flunity/Build/WebGL")]
    public static void BuildWebGLFromMenu() => BuildWebGL();

    /// <summary>
    /// Builds the project's enabled scenes for the WebGL platform.
    /// Output goes to <paramref name="overrideExportPath"/> if provided,
    /// otherwise to `&lt;projectRoot&gt;/Builds/webgl`.
    ///
    /// Invoked headless by `flunity build webgl` via:
    ///     unity -batchmode -projectPath ... -executeMethod FlunityWebGLBuilder.BuildWebGL -quit
    /// (with optional `-exportPath &lt;dir&gt;` to override output location).
    /// </summary>
    public static void BuildWebGL(string overrideExportPath = null)
    {
        string exportPath = overrideExportPath ?? GetCliArg("-exportPath");
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

        // Ensure Brotli compression for production-ish builds; users can
        // override via Player Settings UI for development builds.
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Brotli;

        EditorUserBuildSettings.SwitchActiveBuildTarget(
            BuildTargetGroup.WebGL, BuildTarget.WebGL);

        Debug.Log($"Flunity: building WebGL → {exportPath}");
        BuildPlayerOptions opts = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = exportPath,
            target = BuildTarget.WebGL,
            options = BuildOptions.None,
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
}
