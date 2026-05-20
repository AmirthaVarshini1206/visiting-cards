import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabaseService {
  static const String _storageKey = 'saved_cards';

  // Fetch all saved cards
  Future<List<Map<String, dynamic>>> getCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawData = prefs.getString(_storageKey);
      if (rawData == null) return [];

      final List<dynamic> jsonList = jsonDecode(rawData);
      return jsonList.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print("Error loading local database: $e");
      return [];
    }
  }

  // Save a new card, automatically assigning a unique SL No
  Future<int> saveCard(Map<String, dynamic> cardData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cards = await getCards();

      // Find the next SL No
      int nextSlNo = 1;
      if (cards.isNotEmpty) {
        // Find the maximum SL No currently stored
        final slNos = cards.map((c) {
          final sl = c['sl_no'] ?? c['SL No'] ?? 0;
          return sl is int ? sl : int.tryParse(sl.toString()) ?? 0;
        });
        nextSlNo = (slNos.isEmpty ? 0 : slNos.reduce((a, b) => a > b ? a : b)) + 1;
      }

      // Format card data to match exactly the structure the UI expects
      final newCard = {
        'sl_no': nextSlNo,
        'SL No': nextSlNo, // Keep both for safety with older V2 header mappings
        'organization_type': (cardData['organization_type'] ?? '').toString().toUpperCase(),
        'organization_name': cardData['organization_name'] ?? '',
        'location': cardData['location'] ?? '',
        'point_person': cardData['point_person'] ?? '',
        'department': cardData['department'] ?? '',
        'contact_number': cardData['contact_number'] ?? '',
        'contact_email': cardData['contact_email'] ?? '',
        'address': cardData['address'] ?? '',
        'url': cardData['url'] ?? '',
        'remark': cardData['remark'] ?? 'Local-Upload',
        'timestamp': DateTime.now().toIso8601String(),
      };

      cards.add(newCard);
      await prefs.setString(_storageKey, jsonEncode(cards));
      return nextSlNo;
    } catch (e) {
      throw Exception("Failed to save card locally: $e");
    }
  }

  // Delete a card by SL No
  Future<void> deleteCard(int slNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cards = await getCards();

      cards.removeWhere((c) {
        final sl = c['sl_no'] ?? c['SL No'];
        final parsedSl = sl is int ? sl : int.tryParse(sl.toString()) ?? -1;
        return parsedSl == slNo;
      });

      await prefs.setString(_storageKey, jsonEncode(cards));
    } catch (e) {
      throw Exception("Failed to delete card: $e");
    }
  }

  // Local Duplicate Check
  // Returns duplicate card if found, otherwise null
  Future<Map<String, dynamic>?> checkDuplicate(Map<String, dynamic> cardData) async {
    try {
      final cards = await getCards();

      final String personName = (cardData['point_person'] ?? '').toString().trim().toLowerCase();
      final String contactNumber = (cardData['contact_number'] ?? '').toString().trim();
      final String contactEmail = (cardData['contact_email'] ?? '').toString().trim().toLowerCase();

      if (personName.isEmpty && contactNumber.isEmpty && contactEmail.isEmpty) {
        return null;
      }

      // Helper helper to strip all non-digit characters for phone comparison
      String cleanPhone(String phone) {
        return phone.replaceAll(RegExp(r'\D'), '');
      }

      final String cleanNewPhone = cleanPhone(contactNumber);

      for (var card in cards) {
        final String existingName = (card['point_person'] ?? '').toString().trim().toLowerCase();
        final String existingPhone = (card['contact_number'] ?? '').toString().trim();
        final String existingEmail = (card['contact_email'] ?? '').toString().trim().toLowerCase();

        // 1. Match Name
        if (personName.isNotEmpty && existingName.isNotEmpty) {
          if (personName == existingName) return card;
        }

        // 2. Match Cleaned Phone Number
        if (cleanNewPhone.isNotEmpty && existingPhone.isNotEmpty) {
          final String cleanExistingPhone = cleanPhone(existingPhone);
          if (cleanExistingPhone.isNotEmpty && cleanNewPhone == cleanExistingPhone) {
            return card;
          }
        }

        // 3. Match Email
        if (contactEmail.isNotEmpty && existingEmail.isNotEmpty) {
          if (contactEmail == existingEmail) return card;
        }
      }

      return null;
    } catch (e) {
      print("Error checking local duplicate: $e");
      return null;
    }
  }
}
