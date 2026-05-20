import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/config_provider.dart';
import '../providers/data_provider.dart';
import '../widgets/selected_image.dart';

class BatchProcessingScreen extends ConsumerStatefulWidget {
  final List<XFile> images;

  const BatchProcessingScreen({super.key, required this.images});

  @override
  ConsumerState<BatchProcessingScreen> createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends ConsumerState<BatchProcessingScreen> {
  int _currentIndex = 0;
  bool _isFinished = false;
  final List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _processBatch();
  }

  Future<void> _processBatch() async {
    final config = ref.read(configProvider);
    final api = ref.read(apiServiceProvider);
    api.updateBaseUrl(config.serverHost, config.serverPort);

    for (int i = 0; i < widget.images.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentIndex = i;
      });

      final xFile = widget.images[i];
      try {
        // Extract via API
        final extractResult = await api.extractCard(xFile, config.selectedModel, isWeb: kIsWeb);
        final Map<String, dynamic> data = extractResult["data"];

        // 1. Run local duplicate check
        final duplicate = await ref.read(localDbServiceProvider).checkDuplicate(data);

        if (duplicate == null) {
          // 2. Save locally
          final slNo = await ref.read(localCardsProvider.notifier).addCard(data);

          _results.add({
            "status": "success",
            "message": "Saved locally as #$slNo",
            "file": xFile.name,
            "color": Colors.green,
            "icon": Icons.check_circle
          });
          // Delete local image
          await deleteSelectedImage(xFile);
        } else {
          _results.add({
            "status": "skipped",
            "message": "Duplicate Detected: '${duplicate['point_person']}'",
            "file": xFile.name,
            "color": Colors.orange,
            "icon": Icons.warning_rounded
          });
        }
      } catch (e) {
        _results.add({
          "status": "error",
          "message": e.toString().replaceAll("Exception: Failed to extract card: ", ""),
          "file": xFile.name,
          "color": Colors.red,
          "icon": Icons.error
        });
      }
    }

    if (mounted) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Batch Processing"),
        automaticallyImplyLeading: _isFinished,
      ),
      body: _isFinished ? _buildSummary() : _buildProgress(),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            "Processing ${_currentIndex + 1} of ${widget.images.length}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Extracting and syncing...",
            style: TextStyle(color: Colors.grey),
          )
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final res = _results[index];
              return ListTile(
                leading: Icon(res["icon"], color: res["color"]),
                title: Text(res["file"]),
                subtitle: Text(res["message"], style: TextStyle(color: res["color"])),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Go back to scanner
            },
            icon: const Icon(Icons.done_all),
            label: const Text("Done"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        )
      ],
    );
  }
}
