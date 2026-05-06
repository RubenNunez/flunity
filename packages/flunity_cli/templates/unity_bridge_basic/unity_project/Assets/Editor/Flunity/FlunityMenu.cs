// Adapted from flutter_embed_unity v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

using UnityEditor;

public class FlunityMenu : EditorWindow
{
    private static ProjectExportChecker projectExportChecker = new ProjectExportChecker();

    [MenuItem("Flunity/Build/Android")]
    static void ExportProjectAndroid()
    {
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
}
