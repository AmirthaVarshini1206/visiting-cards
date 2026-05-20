import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  String _baseUrl = "http://localhost:8000"; // Default

  ApiService() {
    _dio.options.headers = {
      "ngrok-skip-browser-warning": "69420",
    };
  }

  void updateBaseUrl(String host, int port) {
    if (port == 443 || host.startsWith("https://")) {
      String cleanHost = host.replaceFirst("https://", "");
      _baseUrl = "https://$cleanHost";
    } else {
      _baseUrl = "http://$host:$port";
    }
    print("🌐 API Base URL updated to: $_baseUrl");
  }

  Future<Map<String, dynamic>> extractCard(dynamic imageFile, String model, {bool isWeb = false}) async {
    try {
      FormData formData;
      if (isWeb) {
        final bytes = await imageFile.readAsBytes();
        formData = FormData.fromMap({
          "file": MultipartFile.fromBytes(bytes, filename: imageFile.name),
          "model": model,
        });
      } else {
        String fileName = imageFile.path.split('/').last;
        formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
          "model": model,
        });
      }

      Response response = await _dio.post(
        "$_baseUrl/extract",
        data: formData,
      );

      return response.data;
    } catch (e) {
      throw Exception("Failed to extract card: $e");
    }
  }

  Future<List<String>> getModels() async {
    try {
      Response response = await _dio.get("$_baseUrl/models");
      return List<String>.from(response.data["models"]);
    } catch (e) {
      // Fallback
      return ["llava", "moondream"];
    }
  }

  Future<Map<String, dynamic>> syncToSheet(Map<String, dynamic> data) async {
    try {
      Response response = await _dio.post(
        "$_baseUrl/sync",
        data: data,
      );
      return response.data;
    } catch (e) {
      throw Exception("Failed to sync to sheet: $e");
    }
  }

  Future<List<dynamic>> getSheetData() async {
    try {
      Response response = await _dio.get("$_baseUrl/data");
      return response.data["data"] ?? [];
    } catch (e) {
      throw Exception("Failed to get sheet data: $e");
    }
  }
}
