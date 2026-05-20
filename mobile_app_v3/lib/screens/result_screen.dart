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
    widget.extractedData.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value?.toString() ?? "");
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
