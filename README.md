# BurpCA-AutoTrust
Automatically install and trust the Burp Suite CA certificate system-wide on rooted Android devices — effortlessly enabling HTTPS interception by integrating Burp’s certificate into the device’s trusted system credentials. Perfect for seamless, device-wide traffic analysis and testing.

## Features:

* Automatically installs and trusts the Burp Suite CA certificate in the Android system trusted credentials.
* Supports Android versions 7 through 15+ (handling legacy `/system/etc/security/cacerts` and new APEX container `/apex/com.android.conscrypt/cacerts` cert locations).
* Works on devices with multiple users.
* Transparent handling of system store location changes.
* Designed specifically to trust the Burp Suite CA certificate with hash `9a5ba575`.
* Support for **Magisk**, **KernelSU**, and **KernelSU** Next root solutions.
* Compatible with devices **with and without mainline Conscrypt updates**.
* Uses **bind mounts across namespaces** (including all Zygote process mount namespaces) to override the APEX container cert directory on Android 14+, ensuring all apps trust the Burp CA.

## Technical Details

Since Android 7 (Nougat), installing user CA certificates system-wide has required root privileges. Traditionally, these certificates could be added by modifying system trusted credentials.

However, starting with Android 14 (API 34), system CA certificates are stored inside an immutable APEX container located at `/apex/com.android.conscrypt/cacerts`. This read-only container significantly complicates the process of adding custom CA certificates system-wide.

To address this, the module mounts a temporary, modified copy of the APEX certificate directory over the original using bind mounts. These mounts are applied not only to the root mount namespace but also explicitly to all relevant **Zygote** process mount namespaces (`zygote` and `zygote64`). This ensures that the added Burp CA certificate is recognized system-wide across all apps and processes.

This solution builds upon and extends the techniques pioneered by the [Adguardcert](https://github.com/AdguardTeam/adguardcert) Magisk module and the [AlwaysTrustUserCerts](https://github.com/NVISOsecurity/AlwaysTrustUserCerts) project, adapting them for compatibility with a broader range of Android versions and root frameworks, including Magisk and KernelSU.

Special thanks to Tim Perry for his detailed analysis and insights shared in [this blog post](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/#how-to-install-system-ca-certificates-in-android-14), which helped illuminate the challenges and solutions involved in handling system CA certificates on Android’s evolving architecture.

## Installation

1. Install the Burp Suite CA certificate as a user certificate on your Android device.
2. Install this module via your root manager (Magisk Manager, KernelSU Manager or KernelSU Next Manager):
`Modules → Install from storage → Select BurpCA AutoTrust ZIP`
3. Reboot your device.
4. The Burp CA certificate will be available and trusted system-wide (`Settings → Security → Trusted Credentials`).

## Usage

* After installation you can intercept HTTPS traffic from apps trusting system CAs using Burp Suite.
* To revoke Burp certificate trust, simply uninstall this module or temporarily disable it using your root manager.

## Important Notes

* This module trusts a single certificate with hash 9a5ba575 corresponding to the Burp Suite CA.
* Installing custom certificates at the system level can expose your device to security risks if misused. Proceed only if you understand the implications.
* Tested on Android 7 through Android 15 on various physical and emulator devices.
* Supports devices with multiple users and transparently handles differences in system certificate storage locations.
* Supports Magisk, KernelSU, and KernelSU Next root frameworks.
* Compatible with devices both with and without mainline Conscrypt updates.

## Certificate Expiry
The Burp Suite CA certificate installed by this module expires on **24-Dec-2027**.

## Changelog

### v1.0
* Initial release supporting Android 7+ and KernelSU/Magisk with APEX handling for Android 14+.
* Added support for Magisk, KernelSU, and KernelSU Next root solutions.
* Added bind mounts across namespaces including Zygote process namespaces for full system trust.

## Credits
* Inspired by the AlwaysTrustUserCerts project.
* Based on techniques detailed by Tim Perry and implemented in the Adguardcert Magisk module.
* Special thanks to all contributors and maintainers in the Android rooting and security community.

## Disclaimer
Use this module at your own risk. Installing custom CA certificates can compromise device security and privacy. This module is intended for ethical security testing and learning purposes only.
