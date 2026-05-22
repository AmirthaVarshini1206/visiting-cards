import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';

class SheetDataScreen extends ConsumerStatefulWidget {
  const SheetDataScreen({super.key});

  @override
  ConsumerState<SheetDataScreen> createState() => _SheetDataScreenState();
}

class _SheetDataScreenState extends ConsumerState<SheetDataScreen> {
  String _searchQuery = "";
  String _selectedChannel = "All";
  String _sortOrder = "Newest First";

  final List<String> _channels = ["All", "UNIVERSITY", "BUSINESS", "CONSULTANCY", "NGO", "STARTUP", "GOVERNMENT"];
  final List<String> _sortOptions = ["Newest First", "Oldest First", "A-Z (Person)", "A-Z (Org)"];

  Future<void> _confirmDelete(BuildContext context, int slNo) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Card"),
        content: const Text("Are you sure you want to permanently delete this card from your device?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await ref.read(localCardsProvider.notifier).deleteCard(slNo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Card deleted successfully"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataState = ref.watch(sheetDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Cards"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(localCardsProvider.notifier).loadCards(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search name, org, email, or phone...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedChannel,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          labelText: "Filter Channel",
                        ),
                        isDense: true,
                        isExpanded: true,
                        items: _channels.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedChannel = val!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortOrder,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          labelText: "Sort By",
                        ),
                        isDense: true,
                        isExpanded: true,
                        items: _sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _sortOrder = val!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Data List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.read(localCardsProvider.notifier).loadCards(),
              child: dataState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildScrollablePlaceholder(
                  context, 
                  Icons.error_outline, 
                  "Failed to load data\n${error.toString()}"
                ),
                data: (data) => _buildList(context, data),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ensures we can always pull-to-refresh even when empty/error
  Widget _buildScrollablePlaceholder(BuildContext context, IconData icon, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(icon, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          message, 
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 18)
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> data) {
    if (data.isEmpty) {
      return _buildScrollablePlaceholder(context, Icons.folder_open, "No cards saved locally yet");
    }

    // Filter and Sort with case-insensitive robust key mapping
    List<Map<String, dynamic>> processedData = [];
    
    for (var rawRow in data) {
      if (rawRow is! Map) continue;
      Map<String, dynamic> row = {};
      rawRow.forEach((key, value) {
        final rawKey = key.toString().toUpperCase().trim();
        row[rawKey] = value;
        // Normalize snake_case keys (e.g., POINT_PERSON -> POINT PERSON)
        final normalizedKey = rawKey.replaceAll('_', ' ');
        row[normalizedKey] = value;
      });
      processedData.add(row);
    }

    List<Map<String, dynamic>> filteredData = processedData.where((row) {
      final person = (row["POINT PERSON"] ?? "").toString().toLowerCase();
      final org = (row["UNIVERSITY"] ?? row["ORGANIZATION NAME"] ?? "").toString().toLowerCase();
      final email = (row["CONTACT EMAIL"] ?? "").toString().toLowerCase();
      final phone = (row["CONTACT NUMBER"] ?? "").toString().toLowerCase();
      final channel = (row["CHANNEL"] ?? row["ORGANIZATION TYPE"] ?? "").toString().toUpperCase();

      bool matchesSearch = _searchQuery.isEmpty || 
          person.contains(_searchQuery.toLowerCase()) || 
          org.contains(_searchQuery.toLowerCase()) || 
          email.contains(_searchQuery.toLowerCase()) || 
          phone.contains(_searchQuery.toLowerCase());
          
      bool matchesChannel = _selectedChannel == "All" || channel == _selectedChannel;

      return matchesSearch && matchesChannel;
    }).toList();

    filteredData.sort((a, b) {
      final aPerson = (a["POINT PERSON"] ?? "").toString().toLowerCase();
      final bPerson = (b["POINT PERSON"] ?? "").toString().toLowerCase();
      final aOrg = (a["UNIVERSITY"] ?? a["ORGANIZATION NAME"] ?? "").toString().toLowerCase();
      final bOrg = (b["UNIVERSITY"] ?? b["ORGANIZATION NAME"] ?? "").toString().toLowerCase();
      
      if (_sortOrder == "Newest First") {
        return processedData.indexOf(a).compareTo(processedData.indexOf(b));
      } else if (_sortOrder == "Oldest First") {
        return processedData.indexOf(b).compareTo(processedData.indexOf(a));
      } else if (_sortOrder == "A-Z (Person)") {
        return aPerson.compareTo(bPerson);
      } else if (_sortOrder == "A-Z (Org)") {
        return aOrg.compareTo(bOrg);
      }
      return 0;
    });

    if (filteredData.isEmpty) {
      return _buildScrollablePlaceholder(context, Icons.search_off, "No matching records found");
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredData.length,
      itemBuilder: (context, index) {
        final row = filteredData[index];
        final person = row["POINT PERSON"] ?? "Unknown Person";
        final org = row["UNIVERSITY"] ?? row["ORGANIZATION NAME"] ?? "Unknown Org";
        final channel = row["CHANNEL"] ?? row["ORGANIZATION TYPE"] ?? "";
        final contact = row["CONTACT NUMBER"] ?? "";
        final email = row["CONTACT EMAIL"] ?? "";
        final role = row["DEPARTMENT"] ?? "";
        
        // Find row number using the first available SL/No column
        String slNo = row["SL NO"]?.toString() ?? row["SL"]?.toString() ?? row["NO"]?.toString() ?? "";
        if (slNo.isEmpty) {
          // Fallback to relative index if no SL column exists
          slNo = "#${(processedData.length - processedData.indexOf(row)).toString()}"; 
        } else {
          slNo = "#$slNo";
        }

        final int parsedSlNo = int.tryParse(row["SL NO"]?.toString() ?? "") ?? 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        person.toString(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          slNo,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        if (parsedSlNo > 0) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDelete(context, parsedSlNo),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (role.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(role.toString(), style: const TextStyle(color: Colors.grey)),
                ],
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(org.toString())),
                    if (channel.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          channel.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (contact.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          contact.toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (email.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(email.toString(), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, duration: 300.ms);
      },
    );
  }
}
