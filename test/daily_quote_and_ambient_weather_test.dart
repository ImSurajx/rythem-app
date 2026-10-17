import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rythem_app/core/ambient/ambient_weather_service.dart';
import 'package:rythem_app/core/ambient/daily_quote_service.dart';
import 'package:rythem_app/core/ambient/location_permission_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DailyQuoteService Tests (Free APIs, 0 signup, 0 keys)', () {
    test('fetches daily quote from primary ZenQuotes endpoint', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'zenquotes.io') {
          return http.Response(
            jsonEncode([
              {
                'q': 'The rhythm of daily habits shapes mastery.',
                'a': 'Anonymous Thinker',
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = DailyQuoteService.instance;
      final quote = await service.getDailyQuote(forceRefresh: true, client: mockClient);

      expect(quote.quote, 'The rhythm of daily habits shapes mastery.');
      expect(quote.author, 'Anonymous Thinker');
    });

    test('falls back to DummyJSON when ZenQuotes returns non-200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'zenquotes.io') {
          return http.Response('Rate limit', 429);
        }
        if (request.url.host == 'dummyjson.com') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'quote': 'Focus creates momentum.',
              'author': 'Marcus Aurelius',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = DailyQuoteService.instance;
      final quote = await service.getDailyQuote(forceRefresh: true, client: mockClient);

      expect(quote.quote, 'Focus creates momentum.');
      expect(quote.author, 'Marcus Aurelius');
    });

    test('falls back to offline curated quote reserve when completely offline', () async {
      final mockClient = MockClient((request) async {
        throw Exception('No network available');
      });

      final service = DailyQuoteService.instance;
      final quote = await service.getDailyQuote(forceRefresh: true, client: mockClient);

      expect(quote.quote.isNotEmpty, isTrue);
      expect(quote.author.isNotEmpty, isTrue);
    });
  });

  group('AmbientWeatherService Open-Meteo & BigDataCloud Tests (Free, 0 signup, 0 keys)', () {
    test('parses Open-Meteo WMO weather codes and BigDataCloud reverse geocode', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'api.open-meteo.com') {
          return http.Response(
            jsonEncode({
              'current': {
                'temperature_2m': 22.4,
                'weather_code': 0, // Clear
                'is_day': 0,
              }
            }),
            200,
          );
        }
        if (request.url.host == 'api.bigdatacloud.net') {
          return http.Response(
            jsonEncode({
              'principalSubdivision': 'Delhi',
              'city': 'New Delhi',
              'locality': 'Mayur Vihar',
              'countryName': 'India',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = AmbientWeatherService.instance;
      final weather = await service.getWeather(
        forceRefresh: true,
        mockCoordinates: const LocationCoordinates(latitude: 28.6139, longitude: 77.2090),
        client: mockClient,
      );

      expect(weather, isNotNull);
      expect(weather!.condition, 'Clear');
      expect(weather.temperatureC, 22);
      expect(weather.location, 'Delhi');
      expect(weather.isLocationBased, isTrue);
    });

    test('WMO code conditions map properly to accurate Diurnal greetings', () {
      final nightTime = DateTime(2026, 10, 18, 1, 30); // 1:30 AM
      final clearWeather = AmbientWeather(
        condition: 'Clear',
        temperatureC: 18,
        fetchedAt: DateTime(2026, 10, 18),
      );

      final greeting = AmbientWeatherService.getGreeting(
        dateTime: nightTime,
        weather: clearWeather,
      );

      // 1 AM is night, NOT morning!
      expect(greeting, 'Clear night');
    });
  });
}
