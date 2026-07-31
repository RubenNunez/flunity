#!/usr/bin/env bash
#
# Type-checks the Unity-side C# templates without opening Unity.
#
# The bridge's C# ships as template source, so a compile error in it only
# surfaces when a user opens their project — long after CI went green. This
# compiles the same files against a real Unity editor's UnityEngine
# assemblies, which takes about a second.
#
# Exits 0 with a notice when no Unity editor or no C# compiler is present:
# CI runners have neither, and this must not be the reason a build fails.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scripts_dir="$repo_root/packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Scripts/Flunity"

if [[ ! -d "$scripts_dir" ]]; then
  echo "check-unity-scripts: no template scripts at $scripts_dir" >&2
  exit 1
fi

if ! command -v csc >/dev/null 2>&1; then
  echo "check-unity-scripts: skipped — no 'csc' on PATH (install Mono)."
  exit 0
fi

# Newest installed editor wins; any 6.x has the assemblies we reference.
hub="/Applications/Unity/Hub/Editor"
editor=""
if [[ -d "$hub" ]]; then
  editor="$(ls -1 "$hub" 2>/dev/null | sort -V | tail -1)"
fi
if [[ -z "$editor" ]]; then
  echo "check-unity-scripts: skipped — no Unity editor found under $hub."
  exit 0
fi

managed="$hub/$editor/PlaybackEngines/WebGLSupport/Managed"
netstandard="$hub/$editor/Unity.app/Contents/Resources/Scripting/NetStandard/ref/2.1.0/netstandard.dll"

if [[ ! -d "$managed" || ! -f "$netstandard" ]]; then
  echo "check-unity-scripts: skipped — $editor lacks WebGL support modules."
  exit 0
fi

refs=()
for dll in "$managed"/UnityEngine*.dll; do
  refs+=("-r:$dll")
done

out="$(mktemp -d)/flunity_scripts.dll"
trap 'rm -rf "$(dirname "$out")"' EXIT

echo "check-unity-scripts: compiling against Unity $editor"
csc -nologo -target:library -nostdlib -noconfig -langversion:9.0 \
    -warnaserror -out:"$out" \
    "-r:$netstandard" "${refs[@]}" \
    "$scripts_dir"/*.cs

echo "check-unity-scripts: OK"
