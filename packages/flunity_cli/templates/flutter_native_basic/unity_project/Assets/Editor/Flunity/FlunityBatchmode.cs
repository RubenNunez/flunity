// Adapted from flutter_embed_unity v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

using UnityEditor;
using UnityEngine;

public class FlunityBatchmode
{
    private static ProjectExportChecker projectExportChecker = new ProjectExportChecker();

    // Functions to export from the command line using Unity batchmode.
    //
    // It is advised to run an export from the Unity Editor first, to make sure your project settings are correct.
    // Checks that open dialogs in the Unity Editor will simply fail on the command line.
    //
    // Make sure to use -quit in your command, to ensure the headless Unity engine always terminates in the end.
    //
    // Unity documentation https://docs.unity3d.com/2022.3/Documentation/Manual/EditorCommandLineArguments.html





    // Export command for Android & iOS. The specific platform is based on `-buildTarget`.
    // -buildTarget Android
    // -buildTarget iOS
    //
    // <unity path> -projectPath <unity project path> -batchmode -buildTarget Android -executeMethod FlunityBatchmode.ExportProject -exportPath <output path> -quit

    public static void ExportProject()
    {
        BuildTarget target = EditorUserBuildSettings.activeBuildTarget;

        if (target == BuildTarget.Android)
        {
            ExportProjectAndroid();
        } 
        else if ( target == BuildTarget.iOS)
        {
            ExportProjectIos();
        }
        else
        {
            throw new System.Exception("Invalid buildtarget during batchmode export.");
        }
    }


    public static void ExportProjectAndroid()
    {
        if (!Application.isBatchMode)
        {
            return;
        }

        Debug.Log("Exporting Android project in batchmode.");

        ApplyAndroidExportSettings();

        ProjectExportCheckerResult result = projectExportChecker.PreCheckAndroid();

#if UNITY_ANDROID
        if (result.IsSuccessful)
        {
            new ProjectExporterAndroid().Export(result.BuildPlayerOptions, result.PrecheckWarnings);
        } else
        {
            throw new System.Exception("Android PreBuid checks failed.");
        }
#else
        throw new System.Exception("Build platform is not Android.");
#endif

    }


    // Batchmode has no GUI to tick these boxes in, so apply the settings the
    // Android library export requires and let the checker verify them. Without
    // this, `flunity build android` aborts on things a human would otherwise
    // set by hand in File -> Build Profiles / Player Settings.
    static void ApplyAndroidExportSettings()
    {
        // "Export Project" — we want a Gradle project (the unityLibrary
        // module), not a finished APK.
        EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

#if UNITY_ANDROID
#if UNITY_6000_0_OR_NEWER
        // Unity 6 defaults to GameActivity; Unity-as-a-Library needs Activity.
        PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.Activity;
#endif
        // ARMv7 + ARM64 only. Do NOT add X86_64: Unity 6 reduced it to
        // "x86-64 (Magic Leap) support is now limited" and the build aborts.
        // x86_64 emulators run ARM64 apps through the emulator's own binary
        // translation instead.
        // ARM64 only. ARMv7 (32-bit) doubles IL2CPP AOT compile time for
        // devices that Play Store 64-bit requirements already retired.
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
#endif

        // Unity needs a JDK to drive its Android SDK tools. When the Hub's
        // OpenJDK module isn't installed, Unity fails with "Failed to update
        // Android SDK package list" — fall back to JAVA_HOME.
        //
        // UnityEditor.Android only exists when Android Build Support is
        // installed and active, same as UnityEditor.iOS.Xcode below.
#if UNITY_ANDROID
        var javaHome = System.Environment.GetEnvironmentVariable("JAVA_HOME");
        if (!string.IsNullOrEmpty(javaHome) && System.IO.Directory.Exists(javaHome))
        {
            UnityEditor.Android.AndroidExternalToolsSettings.jdkRootPath = javaHome;
            Debug.Log("Flunity: using JDK from JAVA_HOME: " + javaHome);
        }
#endif

        AssetDatabase.SaveAssets();
    }

    // public so this function can be called directly from the command line.
    public static void ExportProjectIos()
    {

        if (!Application.isBatchMode)
        {
            return;
        }

        Debug.Log("Exporting iOS project in batchmode.");


        // Using UNITY_IOS preprocessor because 'using UnityEditor.iOS.Xcode' is only available with iOS build tools
        ProjectExportCheckerResult result = projectExportChecker.PreCheckIos();
#if UNITY_IOS
        // Flunity: honor `-flunitySdk simulator` (or `-flunitySdk device`) so
        // `flunity build ios --simulator` produces a Simulator-SDK Xcode
        // project. We restore the original setting on exit so the Editor's
        // persisted PlayerSettings aren't surprise-mutated for the next user.
        string sdkArg = GetArg("-flunitySdk");
        UnityEditor.iOSSdkVersion originalSdk = PlayerSettings.iOS.sdkVersion;
        bool sdkChanged = false;
        if (sdkArg == "simulator")
        {
            Debug.Log("Flunity: targeting iOS Simulator SDK for this build.");
            PlayerSettings.iOS.sdkVersion = UnityEditor.iOSSdkVersion.SimulatorSDK;
            sdkChanged = true;
        }
        else if (sdkArg == "device")
        {
            PlayerSettings.iOS.sdkVersion = UnityEditor.iOSSdkVersion.DeviceSDK;
            sdkChanged = true;
        }

        try
        {
            if (result.IsSuccessful)
            {
                new ProjectExporterIos().Export(result.BuildPlayerOptions, result.PrecheckWarnings);
            }
            else
            {
                throw new System.Exception("iOS PreBuid checks failed.");
            }
        }
        finally
        {
            if (sdkChanged)
            {
                PlayerSettings.iOS.sdkVersion = originalSdk;
            }
        }
#else
        throw new System.Exception("Build platform is not iOS.");
#endif

    }


    // Get the build destination (unityLibrary directory) from the comand line argument -exportPath
    public static string GetExportPath()
    {
        return GetArg("-exportPath");
    }

    private static string GetArg(string name)
    {
        var args = System.Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == name && args.Length > i + 1)
            {
                return args[i + 1];
            }
        }
        return null;
    }
}
