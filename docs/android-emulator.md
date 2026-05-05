# Android Emulator Notes

Android's emulator runs in its own VM. From inside the emulator, `127.0.0.1` and `localhost` point to the **emulator itself**, not your host machine. Two consequences for Flunity dev:

## `10.0.2.2` instead of `127.0.0.1`

Google's emulator exposes the host machine at `10.0.2.2`. `FlunityWebGLConfig.dev()` automatically substitutes `127.0.0.1` → `10.0.2.2` when running on Android. You don't need to do anything.

If your dev server's `host:` is non-loopback (e.g., a LAN IP for a physical device), the substitution is skipped.

## Cleartext HTTP

Dev mode hits `http://10.0.2.2:8080/...`. Production loopback hits `http://127.0.0.1:<random>/...`. Both are HTTP, not HTTPS.

`flunity create` generates a `flutter_app/android/app/src/main/AndroidManifest.xml` and `flutter_app/android/app/src/main/res/xml/network_security_config.xml` that allow cleartext **only** for `127.0.0.1`, `10.0.2.2`, and `localhost`. The rest of the app stays under the default Android cleartext-disabled policy.

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
```

## Physical device, not emulator?

The emulator host swap only applies to Android emulators, but the runtime can't tell — it just sees "Android". If you're testing on a physical device:

1. Find your machine's LAN IP (e.g., `192.168.1.42`).
2. Run with `--dart-define=FLUNITY_DEV_HOST=192.168.1.42`.
3. Make sure the dev server is reachable from the device (firewall, same network).

`flunity doctor` warns when it detects a physical device + `127.0.0.1` dev host.

## iOS simulator

iOS simulator runs on the host kernel, so `127.0.0.1` works directly. The generated `Info.plist` has an `NSAppTransportSecurity` exception scoped to `127.0.0.1` and `localhost`. No action needed.
