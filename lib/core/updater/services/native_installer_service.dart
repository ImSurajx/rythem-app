import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class NativeInstallerService {
  static const MethodChannel _channel =
      MethodChannel('com.rythem.rythem_app/updater');

  final MethodChannel channel;

  NativeInstallerService({MethodChannel? channel})
      : channel = channel ?? _channel;

  /// Checks if the app has permission to install packages on Android 8.0+ (Oreo+).
  /// On non-Android platforms, returns true.
  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    try {
      final canInstall =
          await channel.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } on MissingPluginException {
      debugPrint('Updater MethodChannel not registered; falling back to true.');
      return true;
    } catch (e) {
      debugPrint('canRequestPackageInstalls check failed: $e');
      return true;
    }
  }

  /// Opens the system Settings page for "Install unknown apps" for this app.
  Future<void> openInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      await channel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('openInstallPermissionSettings failed: $e');
    }
  }

  /// Triggers installation of the downloaded APK file.
  /// On Android, launches the native PackageInstaller via FileProvider.
  /// On other platforms, attempts opening the file or fallback browser download.
  Future<bool> installApk(String filePath, {String? fallbackUrl}) async {
    if (kIsWeb || !Platform.isAndroid) {
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        return await openReleasePage(fallbackUrl);
      }
      return false;
    }

    try {
      final success = await channel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return success ?? false;
    } on MissingPluginException {
      debugPrint('Native installer channel missing, opening fallback URL.');
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        return await openReleasePage(fallbackUrl);
      }
      return false;
    } catch (e) {
      debugPrint('Native APK installation failed: $e');
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        return await openReleasePage(fallbackUrl);
      }
      return false;
    }
  }

  /// Opens external release URL in the system browser.
  Future<bool> openReleasePage(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open release URL: $e');
      return false;
    }
  }
}
