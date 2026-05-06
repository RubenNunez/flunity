// Adapted from flutter_embed_unity v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

using System.IO;
using UnityEditor;
using UnityEngine;

public class FlunityMenu : EditorWindow
{
    private static ProjectExportChecker projectExportChecker = new ProjectExportChecker();

    [MenuItem("Flunity/Build/Android")]
    static void ExportProjectAndroid()
    {
        string exportPath = ResolveExportPath("android");
        ProjectExportCheckerResult result = projectExportChecker.PreCheckAndroidWithKnownPath(exportPath);

#if UNITY_ANDROID
        if (result.IsSuccessful)
        {
            new ProjectExporterAndroid().Export(result.BuildPlayerOptions, result.PrecheckWarnings);
        }
#endif
    }

    [MenuItem("Flunity/Build/iOS (Device)")]
    static void ExportProjectIosDevice() => RunIosExport(iOSSdkVersion.DeviceSDK);

    [MenuItem("Flunity/Build/iOS (Simulator)")]
    static void ExportProjectIosSimulator() => RunIosExport(iOSSdkVersion.SimulatorSDK);

    /// <summary>
    /// Shared body for the two iOS menu entries. Saves the current
    /// PlayerSettings.iOS.sdkVersion, flips it to the requested target for
    /// this export, then restores in a finally block so the persisted
    /// project setting isn't surprise-mutated.
    /// </summary>
    static void RunIosExport(iOSSdkVersion sdk)
    {
#if UNITY_IOS
        string exportPath = ResolveExportPath("ios");
        iOSSdkVersion originalSdk = PlayerSettings.iOS.sdkVersion;
        PlayerSettings.iOS.sdkVersion = sdk;
        try
        {
            ProjectExportCheckerResult result = projectExportChecker.PreCheckIosWithKnownPath(exportPath);
            if (result.IsSuccessful)
            {
                new ProjectExporterIos().Export(result.BuildPlayerOptions, result.PrecheckWarnings);
            }
        }
        finally
        {
            PlayerSettings.iOS.sdkVersion = originalSdk;
        }
#endif
    }

    /// <summary>
    /// Resolve the canonical Flunity export path for a given target —
    /// `<unity project>/Builds/<target>/unityLibrary/`. This matches what
    /// `flunity build <target>` from the terminal uses, so the menu and
    /// CLI write to the same place. No dialog, no folder picker, no
    /// "create the folder first" friction — the path is fully deterministic
    /// from the project layout.
    /// </summary>
    static string ResolveExportPath(string targetSubfolder)
    {
        // Application.dataPath returns `<projectRoot>/Assets`; trim that to
        // get the Unity project root.
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        return Path.Combine(projectRoot, "Builds", targetSubfolder, "unityLibrary");
    }
}
