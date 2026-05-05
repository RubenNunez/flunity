#
# Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
# See packages/flunity_bridge/THIRDPARTY.md for full attribution.
#

# Verify the UnityFramework xcframework actually exists. If missing, CocoaPods
# silently ignores it — surface the error early so users don't get a confusing
# "duplicate symbols" or "module not found" later.
framework_path = 'flunity_bridge/UnityFrameworkStubs/StaticFramework/UnityFramework.xcframework'
unless File.exist?(framework_path)
  raise "Error in flunity_bridge.podspec: #{framework_path} not found"
end

Pod::Spec.new do |s|
  s.name             = 'flunity_bridge'
  s.version          = '0.1.0'
  s.summary          = 'Native iOS / Android Unity bridge for Flunity (vendored from flutter_embed_unity).'
  s.description      = <<-DESC
Embeds a native Unity instance inside a Flutter iOS app via UnityFramework.
Mirrors the Android side via flunity_bridge's Kotlin plugin. Originally
adapted from flutter_embed_unity v2.0.0 (MIT).
                       DESC
  s.homepage         = 'https://github.com/RubenNunez/flunity'
  s.license          = { :file => '../THIRDPARTY-LICENSES/flutter_embed_unity-LICENSE.txt' }
  s.author           = { 'Flunity contributors' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flunity_bridge/Sources/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'

  # The vendored xcframework is a compile-time stub. The real UnityFramework
  # is provided at app integration time by `flunity bundle ios` (which copies
  # the user's actual Unity-built framework into the consuming Flutter app's
  # ios/Frameworks tree and re-links).
  s.vendored_frameworks = framework_path
end
