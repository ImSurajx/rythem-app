import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rythem_app/core/ambient/ambient_weather_service.dart';

void main() {
  group('AmbientWeatherService Greeting Tests', () {
    test('1:00 AM (01:00) returns Good night or realistic night weather greeting, never Good morning', () {
      final nightTime = DateTime(2026, 10, 18, 1, 0); // 1:00 AM

      // Without weather
      expect(AmbientWeatherService.getGreeting(dateTime: nightTime), 'Good night');

      // With Clear weather
      final clearWeather = AmbientWeather(
        condition: 'Clear',
        temperatureC: 22,
        isDay: false,
        fetchedAt: nightTime,
      );
      expect(AmbientWeatherService.getGreeting(dateTime: nightTime, weather: clearWeather), 'Clear night');

      // With Rainy weather
      final rainWeather = AmbientWeather(
        condition: 'Rain',
        temperatureC: 19,
        isDay: false,
        fetchedAt: nightTime,
      );
      expect(AmbientWeatherService.getGreeting(dateTime: nightTime, weather: rainWeather), 'Rainy night');
    });

    test('3:30 AM returns Good night / Late night weather greeting', () {
      final lateNight = DateTime(2026, 10, 18, 3, 30);
      expect(AmbientWeatherService.getGreeting(dateTime: lateNight), 'Good night');
    });

    test('8:00 AM returns Good morning or Sunny morning', () {
      final morning = DateTime(2026, 10, 18, 8, 0);
      expect(AmbientWeatherService.getGreeting(dateTime: morning), 'Good morning');

      final sunny = AmbientWeather(
        condition: 'Sunny',
        temperatureC: 25,
        isDay: true,
        fetchedAt: morning,
      );
      expect(AmbientWeatherService.getGreeting(dateTime: morning, weather: sunny), 'Sunny morning');
    });

    test('2:00 PM returns Good afternoon or Sunny afternoon', () {
      final afternoon = DateTime(2026, 10, 18, 14, 0);
      expect(AmbientWeatherService.getGreeting(dateTime: afternoon), 'Good afternoon');

      final cloudy = AmbientWeather(
        condition: 'Cloudy',
        temperatureC: 28,
        isDay: true,
        fetchedAt: afternoon,
      );
      expect(AmbientWeatherService.getGreeting(dateTime: afternoon, weather: cloudy), 'Cloudy afternoon');
    });

    test('7:00 PM returns Good evening or Rainy evening', () {
      final evening = DateTime(2026, 10, 18, 19, 0);
      expect(AmbientWeatherService.getGreeting(dateTime: evening), 'Good evening');

      final rainy = AmbientWeather(
        condition: 'Rain',
        temperatureC: 24,
        isDay: false,
        fetchedAt: evening,
      );
      expect(AmbientWeatherService.getGreeting(dateTime: evening, weather: rainy), 'Rainy evening');
    });

    test('11:00 PM returns Good night', () {
      final night = DateTime(2026, 10, 18, 23, 0);
      expect(AmbientWeatherService.getGreeting(dateTime: night), 'Good night');
    });
  });

  group('AmbientWeatherService API Fetching Tests', () {
    test('Parses wttr.in payload accurately', () async {
      final mockClient = MockClient((request) async {
        final mockJson = {
          'current_condition': [
            {
              'temp_C': '26',
              'weatherDesc': [
                {'value': 'Partly cloudy'}
              ],
            }
          ],
          'nearest_area': [
            {
              'areaName': [
                {'value': 'Bengaluru'}
              ]
            }
          ]
        };
        return http.Response(jsonEncode(mockJson), 200);
      });

      final weather = await AmbientWeatherService.instance.getWeather(
        forceRefresh: true,
        client: mockClient,
      );

      expect(weather, isNotNull);
      expect(weather!.temperatureC, 26);
      expect(weather.condition, 'Partly Cloudy');
      expect(weather.location, 'Bengaluru');
    });

    test('Handles network error gracefully by returning cached or null without throwing', () async {
      final failingClient = MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final service = AmbientWeatherService.instance;
      service.setMockWeather(null);

      final result = await service.getWeather(
        forceRefresh: true,
        client: failingClient,
      );

      expect(result, isNull);
    });
  });
}
