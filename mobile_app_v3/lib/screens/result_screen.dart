import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/data_provider.dart';
import '../widgets/selected_image.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> extractedData;
  final XFile xFile;

  const ResultScreen({
    super.key,
    required this.extractedData,
    required this.xFile,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    
    // Debug: Print what data we received
    print("DEBUG: Extracted data keys: ${widget.extractedData.keys.toList()}");
    print("DEBUG: Extracted data: $widget.extractedData");
    
    widget.extractedData.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value?.toString() ?? "");
      print("DEBUG: Controller[$key] = '${value?.toString() ?? ""}''");
    });
    _checkDataQuality();
  }

  void _checkDataQuality() {
    // Warn user if critical fields are missing or contain placeholder values
    print("DEBUG: Checking data quality...");
    print("DEBUG: All controllers: ${_controllers.keys.toList()}");
    
    final pointPerson = widget.extractedData['point_person']?.toString().toLowerCase() ?? '';
    final orgName = widget.extractedData['organization_name']?.toString().toLowerCase() ?? '';
    
    print("DEBUG: point_person from widget.extractedData: '$pointPerson'");
    print("DEBUG: organization_name from widget.extractedData: '$orgName'");
    print("DEBUG: point_person controller value: '${_controllers['point_person']?.text ?? 'NOT FOUND'}'");
    print("DEBUG: organization_name controller value: '${_controllers['organization_name']?.text ?? 'NOT FOUND'}'");
    
    if (pointPerson.isEmpty || pointPerson.contains('not found') || pointPerson.contains('unknown')) {
      _showWarningDialog('Missing Name', 'Could not extract person name. Please fill it in manually.');
    } else if (orgName.isEmpty || orgName.contains('not found') || orgName.contains('unknown')) {
      _showWarningDialog('Missing Organization', 'Could not extract organization name. Please fill it in manually.');
    }
  }

  void _showWarningDialog(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _syncAndClean() async {
    setState(() => _isSyncing = true);
    try {
      // Collect edited data
      Map<String, dynamic> finalData = {};
      _controllers.forEach((key, controller) {
        finalData[key] = controller.text;
      });

      // Validate critical fields before saving
      final pointPerson = finalData['point_person']?.toString().trim() ?? '';
      final orgName = finalData['organization_name']?.toString().trim() ?? '';
      
      if (pointPerson.isEmpty || pointPerson.toLowerCase().contains('not found')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Person name cannot be empty"), backgroundColor: Colors.red),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }
      
      if (orgName.isEmpty || orgName.toLowerCase().contains('not found')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Organization name cannot be empty"), backgroundColor: Colors.red),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }

      // 1. Local Duplicate Check with user confirmation
      final duplicate = await ref.read(localDbServiceProvider).checkDuplicate(finalData);
      if (duplicate != null && mounted) {
        bool saveAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Duplicate Detected"),
            content: Text("A card for '${duplicate['point_person']}' from '${duplicate['organization_name']}' already exists locally. Save anyway?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text("Save Anyway"),
              ),
            ],
          ),
        ) ?? false;

        if (!saveAnyway) {
          setState(() => _isSyncing = false);
          return;
        }
      }

      // 2. Save locally
      final slNo = await ref.read(localCardsProvider.notifier).addCard(finalData);

      // 3. Delete local image as requested by user
      await deleteSelectedImage(widget.xFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Successfully saved locally as #$slNo! Local photo deleted."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Results"),
        actions: [
          if (!_isSyncing)
            TextButton.icon(
              onPressed: _syncAndClean, 
              icon: const Icon(Icons.save_rounded),
              label: const Text("Save & Close"),
            ),
        ],
      ),
      body: _isSyncing 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: buildSelectedImage(widget.xFile),
                ),
                const SizedBox(height: 24),
                ..._controllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key.replaceAll("_", " ").toUpperCase(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
