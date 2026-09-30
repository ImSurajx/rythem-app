import 'dart:io';
import 'package:flutter/services.dart';

class StoragePermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.rythem.rythem_app/storage_permission');

  /// Checks whether the app currently holds storage permission (All Files access on Android 11+, or WRITE_EXTERNAL_STORAGE on earlier Android versions).
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('hasStoragePermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the system permission dialog or opens the system settings page for All Files access.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestStoragePermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens application settings page.
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }
}
