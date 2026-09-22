// Adapted from flutter_embed_unity v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

internal abstract class ProjectExporter {
    internal void Export(BuildPlayerOptions buildPlayerOptions, List<string> precheckWarnings)
    {
        // Both export routes (FlunityMenu and FlunityBatchmode) funnel through
        // here, so this is the one place that can guarantee they build from the
        // same render-pipeline state. See the method doc for why that matters.
        PrimeRenderPipelinePlatformDetection();

        // This executes the build:
        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);

        if (report.summary.result != BuildResult.Succeeded) {
            Debug.LogError("Building project for Flutter failed");
            
            if (Application.isBatchMode) {

                // throwing an exception shows an error on the command line, exit(1) doesn't.
                throw new System.Exception("Building project for Flutter failed");
                // EditorApplication.Exit(1);
            }
        }
        else {
            TransformExportedProject(buildPlayerOptions.locationPathName);

            // Debug.Log doesn't work until after BuildPipeline.BuildPlayer has executed
            foreach(var log in precheckWarnings) {
                Debug.LogWarning(log);
            }
            Debug.Log($"Building project for Flutter succeeded");

            if (Application.isBatchMode) {
                EditorApplication.Exit(0);
            }
        }
    }

    /// <summary>
    /// Populates URP's cached platform info before the build, so batchmode
    /// exports strip the same shader variants as Editor exports.
    ///
    /// URP caches "is SHADER_API_MOBILE defined for the active build target?"
    /// in the static <c>PlatformAutoDetect.isShaderAPIMobileDefined</c>, which
    /// defaults to <c>false</c> and is only ever assigned by the
    /// <c>UniversalRenderer</c> constructor — i.e. the first time something
    /// actually renders. A `-batchmode -nographics` export never renders, so
    /// the flag stays <c>false</c>. URP's build-time shader stripping
    /// (ShaderBuildPreprocessor -> DecalRendererFeature.GetTechnique ->
    /// IsAutomaticDBuffer) reads that stale flag, so a Decal Renderer Feature
    /// left on the default "Automatic" technique resolves to DBuffer at build
    /// time while the mobile player resolves it to ScreenSpace at runtime. The
    /// variants the player needs are stripped and every material renders black.
    ///
    /// That is exactly why `flunity build ios` and `Flunity/Build/iOS (...)`
    /// disagreed: an Editor that has drawn a Scene or Game view already has the
    /// flag populated, a fresh batchmode process never does. Unity issue:
    /// https://issuetracker.unity3d.com/issues/urp-all-materials-render-black-when-building-via-batchmode-or-without-rendering-scene-slash-game-view-in-editor-if-decal-renderer-technique-is-set-to-automatic
    ///
    /// <c>Initialize()</c> only reads GraphicsSettings and Application.platform,
    /// so it is safe (and cheap) with no graphics device — which keeps
    /// `flunity build` usable on headless CI. It is internal to URP, hence
    /// reflection; every step is null-guarded, so projects on the Built-in
    /// pipeline, or on a future URP that renames this, simply no-op.
    ///
    /// Belt-and-braces alternative, if you would rather not depend on this at
    /// all: set the Decal Renderer Feature's Technique explicitly (Screen Space
    /// on mobile) instead of leaving it on Automatic, which takes the stale flag
    /// out of the decision entirely.
    /// </summary>
    private static void PrimeRenderPipelinePlatformDetection()
    {
        try
        {
            Type platformAutoDetect = Type.GetType(
                "UnityEngine.Rendering.Universal.PlatformAutoDetect, Unity.RenderPipelines.Universal.Runtime");
            MethodInfo initialize = platformAutoDetect?.GetMethod(
                "Initialize",
                BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);

            if (initialize == null)
            {
                // Not a URP project (or URP moved it) — nothing to prime.
                return;
            }

            initialize.Invoke(null, null);
        }
        catch (Exception e)
        {
            // Never fail a build over this: the worst case is the pre-existing
            // Unity behaviour we are working around.
            Debug.LogWarning(
                "Flunity: could not prime URP platform detection before the build " +
                $"({e.Message}). If materials render black in the player, set your " +
                "Decal Renderer Feature's Technique explicitly instead of 'Automatic'.");
        }
    }

    protected abstract void TransformExportedProject(string exportPath);
}
