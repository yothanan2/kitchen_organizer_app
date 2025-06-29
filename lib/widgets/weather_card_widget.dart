// lib/widgets/weather_card_widget.dart
// UPDATED: Improved the _getGlowColor function to handle 'Overcast' and enhance the sunny glow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

// Helper functions kept within the file to be self-contained.
Color _getWeatherCardColor(String weatherDescription) {
  String lowerCaseDesc = weatherDescription.toLowerCase();
  if (lowerCaseDesc.contains('clear') || lowerCaseDesc.contains('sun')) return Colors.amber.shade100;
  if (lowerCaseDesc.contains('cloudy') || lowerCaseDesc.contains('overcast')) return Colors.blueGrey.shade50;
  if (lowerCaseDesc.contains('rain') || lowerCaseDesc.contains('drizzle') || lowerCaseDesc.contains('showers')) return Colors.lightBlue.shade100;
  if (lowerCaseDesc.contains('snow')) return Colors.blue.shade50;
  if (lowerCaseDesc.contains('thunderstorm')) return Colors.indigo.shade100;
  if (lowerCaseDesc.contains('fog')) return Colors.grey.shade200;
  return Colors.grey.shade100;
}

Color _getTextColor(Color backgroundColor) {
  return backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

// --- THIS IS THE UPDATED FUNCTION ---
Color _getGlowColor(String weatherDescription) {
  String lowerCaseDesc = weatherDescription.toLowerCase();
  if (lowerCaseDesc.contains('clear') || lowerCaseDesc.contains('sun')) {
    // Made the sunny glow a bit more intense
    return Colors.yellow.shade700.withOpacity(0.9);
  }
  if (lowerCaseDesc.contains('rain') || lowerCaseDesc.contains('drizzle') || lowerCaseDesc.contains('showers')) {
    return Colors.blue.withOpacity(0.7);
  }
  if (lowerCaseDesc.contains('thunderstorm')) {
    return Colors.red.withOpacity(0.8);
  }
  if (lowerCaseDesc.contains('snow')) {
    return Colors.lightBlue.shade200.withOpacity(0.9);
  }
  // ADDED 'overcast' to this condition
  if (lowerCaseDesc.contains('cloudy') || lowerCaseDesc.contains('overcast') || lowerCaseDesc.contains('fog')) {
    return Colors.grey.withOpacity(0.7);
  }
  return Colors.transparent; // No glow for unknown conditions
}


class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    return weatherAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Card(
        color: Colors.red.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Weather Error: ${err.toString()}', style: TextStyle(color: Colors.red.shade900)),
        ),
      ),
      data: (weather) {
        Color cardColor = _getWeatherCardColor(weather.dailyWeatherDescription);
        Color textColor = _getTextColor(cardColor);
        Color glowColor = _getGlowColor(weather.dailyWeatherDescription);
        final precipitationInfo = weather.findFirstPrecipitation();

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 20.0, // Increased blur for a softer glow
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current: ${weather.currentTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        Text('${weather.weatherIcon} ${weather.weatherDescription}', style: TextStyle(fontSize: 16, color: textColor)),
                        const SizedBox(height: 8),
                        Text('Today: ${weather.dailyWeatherIcon} ${weather.dailyWeatherDescription}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                        if (precipitationInfo != null) ...[
                          const SizedBox(height: 8),
                          Text('❗️ $precipitationInfo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.9))),
                        ]
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Max: ${weather.maxTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
                      Text('Min: ${weather.minTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}