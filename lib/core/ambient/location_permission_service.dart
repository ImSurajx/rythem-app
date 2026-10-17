import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() => '$latitude,$longitude';
}

class LocationPermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.rythem.rythem_app/location_permission');

  /// Mock coordinates or permission for testing
  @visibleForTesting
  static bool? mockPermissionGranted;
  @visibleForTesting
  static LocationCoordinates? mockCoordinates;

  /// Checks whether the user has granted coarse or fine location permission.
  static Future<bool> hasLocationPermission() async {
    if (mockPermissionGranted != null) return mockPermissionGranted!;
    if (!Platform.isAndroid) return false;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('hasLocationPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the system location permission dialog.
  static Future<bool> requestLocationPermission() async {
    if (mockPermissionGranted != null) return mockPermissionGranted!;
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestLocationPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the last known GPS/Network location coordinates of the device.
  static Future<LocationCoordinates?> getLocationCoordinates() async {
    if (mockCoordinates != null) return mockCoordinates;
    if (!Platform.isAndroid) return null;
    try {
      final dynamic raw = await _channel.invokeMethod('getLocation');
      if (raw is Map) {
        final lat = (raw['latitude'] as num?)?.toDouble();
        final lon = (raw['longitude'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          return LocationCoordinates(latitude: lat, longitude: lon);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
