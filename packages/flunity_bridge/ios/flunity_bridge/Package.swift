// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

// created based on https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors


import PackageDescription

let package = Package(
    name: "flunity_bridge",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            // If the plugin name contains "_", replace with "-" for the library name.
            name: "flunity-bridge",
            // This is important. The default linking type is `static` - override this to `dynamic`.
            // Without this, archive builds (eg TestFlight, ad-hoc Release Testing, production release)
            // will crash on startup with the following error:
            // > symbol not found in flat namespace '_FlunityBridge_sendToFlutter'
            // The reason is complex. See https://github.com/learntoflutter/flutter_embed_unity/issues/74
            type: .dynamic,
            targets: ["flunity_bridge"])
    ],
    dependencies: [
        // Provided by Flutter's build system at ios/Flutter/ephemeral/Packages/
        // .packages/FlutterFramework. Requires Flutter 3.41+; our floor is 3.44.
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "flunity_bridge",
            dependencies: [
                "UnityFramework",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [
                // If your plugin requires a privacy manifest
                // (e.g. if it uses any required reason APIs), update the PrivacyInfo.xcprivacy file
                // to describe your plugin's privacy impact, and then uncomment this line.
                // For more information, see:
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ],
            linkerSettings: [
                // The vendored UnityFramework xcframework is a symbol-less stub
                // (see UnityFrameworkStubs/). The real UnityFramework is built
                // by the consuming app from Unity's Xcode sub-project, so
                // `_OBJC_CLASS_$_UnityFramework` cannot be resolved at link
                // time here. Defer it to dyld — the CocoaPods equivalent is
                // `OTHER_LDFLAGS = -undefined dynamic_lookup` in the podspec.
                .unsafeFlags(["-Xlinker", "-undefined", "-Xlinker", "dynamic_lookup"]),
            ]
        ),
        .binaryTarget(
            name: "UnityFramework",
            // SPM needs the version of the XCFramework stub which contains just a raw static 
            // library (.a). The static framework version is used when building with Cocoapods, 
            // which does not know how to handle this kind of static library
            path: "UnityFrameworkStubs/StaticLibrary/UnityFramework.xcframework"
        )
    ]
)
