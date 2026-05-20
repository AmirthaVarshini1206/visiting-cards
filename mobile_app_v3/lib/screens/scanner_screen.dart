import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/config_provider.dart';
import 'result_screen.dart';
import 'batch_processing_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  bool get _supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && !_supportsCamera) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera capture is not available on this platform.")),
        );
      }
      return;
    }

    if (source == ImageSource.gallery) {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        if (images.length == 1) {
          _processImage(images.first);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (c) => BatchProcessingScreen(images: images),
            ),
          );
        }
      }
    } else {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        _processImage(image);
      }
    }
  }

  Future<void> _processImage(XFile xFile) async {
    setState(() => _isProcessing = true);

    try {
      final config = ref.read(configProvider);
      final api = ref.read(apiServiceProvider);
      api.updateBaseUrl(config.serverHost, config.serverPort);

      final result = await api.extractCard(xFile, config.selectedModel, isWeb: kIsWeb);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => ResultScreen(
              extractedData: result["data"],
              xFile: xFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Card")),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const CircularProgressIndicator(),
                   const SizedBox(height: 24),
                   const Text("Analyzing with Local AI...") .animate(onPlay: (controller) => controller.repeat())
                       .fadeIn(duration: 500.ms)
                       .then()
                       .fadeOut(duration: 500.ms),
                   const SizedBox(height: 8),
                   Text(
                     "Running ${ref.watch(configProvider).selectedModel} on PC",
                     style: const TextStyle(color: Colors.grey, fontSize: 12),
                   ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_supportsCamera) ...[
                    _buildOption(
                      context,
                      "Take a Photo",
                      Icons.camera_alt_rounded,
                      () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildOption(
                    context,
                    "Choose from Gallery",
                    Icons.photo_library_rounded,
                    () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ).animate().fadeIn().slideY(begin: 0.1),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
