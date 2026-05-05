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

    [MenuItem("Flunity/Build/iOS")]
    static void ExportProjectIos()
    {
        // Using UNITY_IOS preprocessor because 'using UnityEditor.iOS.Xcode' is only available with iOS build tools
        ProjectExportCheckerResult result = projectExportChecker.PreCheckIos();
#if UNITY_IOS
        if(result.IsSuccessful) {
            new ProjectExporterIos().Export(result.BuildPlayerOptions, result.PrecheckWarnings);
        }
#endif
    }
}
