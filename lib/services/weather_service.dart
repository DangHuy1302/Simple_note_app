import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  final String city;
  final double temperatureC;
  final String description;
  final String iconCode;
  final double latitude;
  final double longitude;
  final int? airQualityIndex;
  final String? airQualityLabel;
  final String locationImageUrl;
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.city,
    required this.temperatureC,
    required this.description,
    required this.iconCode,
    required this.latitude,
    required this.longitude,
    required this.locationImageUrl,
    this.airQualityIndex,
    this.airQualityLabel,
    required this.fetchedAt,
  });
}

class WeatherService {
  final String apiKey;
  final String city;

  const WeatherService({required this.apiKey, required this.city});

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<WeatherSnapshot?> fetchCurrentWeather() async {
    if (!isConfigured) return null;

    final uri = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric&lang=vi',
    );

    return _fetchWeatherFromUri(uri, cityFallback: city);
  }

  Future<WeatherSnapshot?> fetchCurrentWeatherByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    if (!isConfigured) return null;

    final uri = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=vi',
    );

    return _fetchWeatherFromUri(uri, cityFallback: city);
  }

  Future<WeatherSnapshot?> _fetchWeatherFromUri(
    Uri uri, {
    required String cityFallback,
  }) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final weatherList = data['weather'] as List<dynamic>?;
    final main = data['main'] as Map<String, dynamic>?;
    if (weatherList == null || weatherList.isEmpty || main == null) {
      return null;
    }

    final weather = weatherList.first as Map<String, dynamic>;
    final coord = data['coord'] as Map<String, dynamic>?;
    final latitude = ((coord?['lat'] as num?) ?? 0).toDouble();
    final longitude = ((coord?['lon'] as num?) ?? 0).toDouble();

    final aqi = await _fetchAirQualityIndex(
      latitude: latitude,
      longitude: longitude,
    );

    return WeatherSnapshot(
      city: (data['name'] as String?) ?? cityFallback,
      temperatureC: ((main['temp'] as num?) ?? 0).toDouble(),
      description: (weather['description'] as String?) ?? 'Không rõ',
      iconCode: (weather['icon'] as String?) ?? '01d',
      latitude: latitude,
      longitude: longitude,
      airQualityIndex: aqi,
      airQualityLabel: _airQualityLabel(aqi),
      locationImageUrl: _buildLocationImageUrl(
        latitude: latitude,
        longitude: longitude,
      ),
      fetchedAt: DateTime.now(),
    );
  }

  Future<int?> _fetchAirQualityIndex({
    required double latitude,
    required double longitude,
  }) async {
    if (latitude == 0 && longitude == 0) return null;

    final uri = Uri.parse(
      'https://api.openweathermap.org/data/2.5/air_pollution?lat=$latitude&lon=$longitude&appid=$apiKey',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['list'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      return null;
    }

    final first = list.first as Map<String, dynamic>;
    final main = first['main'] as Map<String, dynamic>?;
    return (main?['aqi'] as num?)?.toInt();
  }

  String? _airQualityLabel(int? aqi) {
    switch (aqi) {
      case 1:
        return 'Rất tốt';
      case 2:
        return 'Tốt';
      case 3:
        return 'Trung bình';
      case 4:
        return 'Kém';
      case 5:
        return 'Rất kém';
      default:
        return null;
    }
  }

  String _buildLocationImageUrl({
    required double latitude,
    required double longitude,
  }) {
    return 'https://static-maps.yandex.ru/1.x/?lang=en_US&ll=$longitude,$latitude&z=12&size=650,300&l=map&pt=$longitude,$latitude,pm2rdm';
  }
}
