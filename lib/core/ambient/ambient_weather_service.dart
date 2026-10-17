import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Snapshot of real-time ambient weather conditions.
class AmbientWeather {
  final String condition;
  final int temperatureC;
  final String? location;
  final bool isDay;
  final DateTime fetchedAt;

  const AmbientWeather({
    required this.condition,
    required this.temperatureC,
    this.location,
    this.isDay = true,
    required this.fetchedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmbientWeather &&
          runtimeType == other.runtimeType &&
          condition == other.condition &&
          temperatureC == other.temperatureC &&
          location == other.location &&
          isDay == other.isDay;

  @override
  int get hashCode =>
      condition.hashCode ^
      temperatureC.hashCode ^
      (location?.hashCode ?? 0) ^
      isDay.hashCode;
}

/// Service that fetches real weather conditions ambiently (without requiring GPS or API keys)
/// and produces contextual greetings based on real weather and natural diurnal time periods.
class AmbientWeatherService {
  AmbientWeatherService._();
  static final AmbientWeatherService instance = AmbientWeatherService._();

  AmbientWeather? _cachedWeather;
  AmbientWeather? get cachedWeather => _cachedWeather;

  /// Visible for testing to inject mock weather.
  void setMockWeather(AmbientWeather? weather) {
    _cachedWeather = weather;
  }

  /// Fetches real weather using wttr.in with strict timeout and fallback.
  Future<AmbientWeather?> getWeather({
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh && _cachedWeather != null) {
      final age = now.difference(_cachedWeather!.fetchedAt);
      if (age < const Duration(minutes: 30)) {
        return _cachedWeather;
      }
    }

    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('https://wttr.in/?format=j1');
      final response = await httpClient
          .get(uri, headers: {'User-Agent': 'curl/8.4'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final current = (data['current_condition'] as List?)?.firstOrNull;
          if (current is Map<String, dynamic>) {
            final tempC = int.tryParse('${current['temp_C']}') ?? 20;
            final descList = current['weatherDesc'] as List?;
            final desc = descList?.isNotEmpty == true
                ? '${descList!.first['value']}'.trim()
                : 'Clear';

            String? area;
            final nearest = (data['nearest_area'] as List?)?.firstOrNull;
            if (nearest is Map<String, dynamic>) {
              final areaList = nearest['areaName'] as List?;
              if (areaList?.isNotEmpty == true) {
                area = '${areaList!.first['value']}'.trim();
              }
            }

            final hour = now.hour;
            final isDay = hour >= 6 && hour < 19;

            final weather = AmbientWeather(
              condition: _cleanCondition(desc),
              temperatureC: tempC,
              location: area,
              isDay: isDay,
              fetchedAt: now,
            );
            _cachedWeather = weather;
            return weather;
          }
        }
      }
    } catch (_) {
      // Network failure, timeout, or rate-limit: silently fall back to cached or diurnal
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    return _cachedWeather;
  }

  static String _cleanCondition(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('thunder') || lower.contains('storm')) return 'Thunderstorm';
    if (lower.contains('heavy rain') || lower.contains('torrential')) return 'Heavy Rain';
    if (lower.contains('rain') || lower.contains('shower')) return 'Rain';
    if (lower.contains('drizzle')) return 'Drizzle';
    if (lower.contains('snow') || lower.contains('blizzard') || lower.contains('sleet')) return 'Snow';
    if (lower.contains('fog') || lower.contains('mist') || lower.contains('haze')) return 'Mist';
    if (lower.contains('partly cloudy')) return 'Partly Cloudy';
    if (lower.contains('cloud') || lower.contains('overcast')) return 'Cloudy';
    if (lower.contains('sunny')) return 'Sunny';
    if (lower.contains('clear')) return 'Clear';
    return raw;
  }

  /// Generates a realistic greeting reflecting the actual time-of-day and live weather.
  ///
  /// Diurnal breakdown:
  /// - 00:00 - 04:59: Late Night (1am is night, NOT morning) -> "Good night", "Clear night", "Rainy night", etc.
  /// - 05:00 - 11:59: Morning -> "Good morning", "Sunny morning", "Rainy morning", etc.
  /// - 12:00 - 16:59: Afternoon -> "Good afternoon", "Sunny afternoon", "Rainy afternoon", etc.
  /// - 17:00 - 20:59: Evening -> "Good evening", "Clear evening", "Rainy evening", etc.
  /// - 21:00 - 23:59: Night -> "Good night", "Clear night", "Rainy night", etc.
  static String getGreeting({DateTime? dateTime, AmbientWeather? weather}) {
    final now = dateTime ?? DateTime.now();
    final hour = now.hour;

    final cond = weather?.condition.toLowerCase() ?? '';

    // Diurnal Classification
    if (hour < 5) {
      // 12:00 AM - 04:59 AM: Late Night
      if (cond.contains('rain') || cond.contains('drizzle')) return 'Rainy night';
      if (cond.contains('thunder') || cond.contains('storm')) return 'Stormy night';
      if (cond.contains('snow')) return 'Snowy night';
      if (cond.contains('cloud') || cond.contains('overcast')) return 'Cloudy night';
      if (cond.contains('mist') || cond.contains('fog')) return 'Misty night';
      if (cond.contains('clear')) return 'Clear night';
      return 'Good night';
    } else if (hour < 12) {
      // 05:00 AM - 11:59 AM: Morning
      if (cond.contains('rain') || cond.contains('drizzle')) return 'Rainy morning';
      if (cond.contains('thunder') || cond.contains('storm')) return 'Stormy morning';
      if (cond.contains('snow')) return 'Snowy morning';
      if (cond.contains('cloud') || cond.contains('overcast')) return 'Cloudy morning';
      if (cond.contains('mist') || cond.contains('fog')) return 'Misty morning';
      if (cond.contains('sun') || cond.contains('clear')) return 'Sunny morning';
      return 'Good morning';
    } else if (hour < 17) {
      // 12:00 PM - 04:59 PM: Afternoon
      if (cond.contains('rain') || cond.contains('drizzle')) return 'Rainy afternoon';
      if (cond.contains('thunder') || cond.contains('storm')) return 'Stormy afternoon';
      if (cond.contains('snow')) return 'Snowy afternoon';
      if (cond.contains('cloud') || cond.contains('overcast')) return 'Cloudy afternoon';
      if (cond.contains('mist') || cond.contains('fog') || cond.contains('haze')) return 'Hazy afternoon';
      if (cond.contains('sun') || cond.contains('clear')) return 'Sunny afternoon';
      return 'Good afternoon';
    } else if (hour < 21) {
      // 05:00 PM - 08:59 PM: Evening
      if (cond.contains('rain') || cond.contains('drizzle')) return 'Rainy evening';
      if (cond.contains('thunder') || cond.contains('storm')) return 'Stormy evening';
      if (cond.contains('snow')) return 'Snowy evening';
      if (cond.contains('cloud') || cond.contains('overcast')) return 'Cloudy evening';
      if (cond.contains('mist') || cond.contains('fog')) return 'Misty evening';
      if (cond.contains('clear')) return 'Clear evening';
      return 'Good evening';
    } else {
      // 09:00 PM - 11:59 PM: Night
      if (cond.contains('rain') || cond.contains('drizzle')) return 'Rainy night';
      if (cond.contains('thunder') || cond.contains('storm')) return 'Stormy night';
      if (cond.contains('snow')) return 'Snowy night';
      if (cond.contains('cloud') || cond.contains('overcast')) return 'Cloudy night';
      if (cond.contains('mist') || cond.contains('fog')) return 'Misty night';
      if (cond.contains('clear')) return 'Clear night';
      return 'Good night';
    }
  }

  /// Appropriate icon for the ambient weather condition.
  static IconData getWeatherIcon(AmbientWeather weather, {int? hour}) {
    final h = hour ?? DateTime.now().hour;
    final isNight = h < 5 || h >= 20;
    final cond = weather.condition.toLowerCase();

    if (cond.contains('thunder') || cond.contains('storm')) {
      return Icons.thunderstorm_rounded;
    }
    if (cond.contains('rain') || cond.contains('drizzle') || cond.contains('shower')) {
      return Icons.water_drop_rounded;
    }
    if (cond.contains('snow') || cond.contains('blizzard') || cond.contains('ice')) {
      return Icons.ac_unit_rounded;
    }
    if (cond.contains('mist') || cond.contains('fog') || cond.contains('haze')) {
      return Icons.blur_on_rounded;
    }
    if (cond.contains('cloud') || cond.contains('overcast')) {
      return Icons.cloud_rounded;
    }
    if (isNight) {
      return Icons.nightlight_round;
    }
    return Icons.wb_sunny_rounded;
  }
}
