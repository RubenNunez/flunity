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
        EnsureBuildsPath("android");
        ProjectExportCheckerResult result = projectExportChecker.PreCheckAndroid();

#if UNITY_ANDROID
        if(result.IsSuccessful) {
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
        EnsureBuildsPath("ios");
        iOSSdkVersion originalSdk = PlayerSettings.iOS.sdkVersion;
        PlayerSettings.iOS.sdkVersion = sdk;
        try
        {
            ProjectExportCheckerResult result = projectExportChecker.PreCheckIos();
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
    /// Pre-create `<unity project>/Builds/<target>/unityLibrary/` so the
    /// folder picker has somewhere to land on first run. Without this the
    /// upstream picker rejects the user's selection because the canonical
    /// Flunity path doesn't exist yet, and they have to "New Folder" three
    /// times in a row.
    /// </summary>
    static void EnsureBuildsPath(string targetSubfolder)
    {
        // Application.dataPath returns `<projectRoot>/Assets`; trim that to
        // get the project root.
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        string buildsTarget = Path.Combine(projectRoot, "Builds", targetSubfolder, "unityLibrary");
        Directory.CreateDirectory(buildsTarget);
    }
}
