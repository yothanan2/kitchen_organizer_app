
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final String? apiKey = dotenv.env['API_KEY'];

  Future<void> fetchData() async {
    if (apiKey == null) {
      debugPrint('API Key not found in .env file');
      return;
    }

    // final response = await http.get(
    //   Uri.parse('https://api.example.com/data'),
    //   headers: {'Authorization': 'Bearer $apiKey'},
    // );

    // if (response.statusCode == 200) {
    //   print('Successfully fetched data');
    // } else {
    //   print('Failed to fetch data');
    // }
  }
}
