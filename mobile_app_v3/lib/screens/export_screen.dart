import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_service.dart';
import '../services/local_db_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _selectedFilter = "All";
  bool _isExporting = false;

  final List<String> _filterOptions = [
    "All",
    "UNIVERSITY",
    "BUSINESS",
    "CONSULTANCY",
    "NGO",
    "STARTUP",
    "GOVERNMENT"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Export Cards"),
        elevation: 0,
      ),
      body: _buildExportView(context),
    );
  }

  Widget _buildExportView(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
              ],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Export Your Cards",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                const SizedBox(height: 8),
                Text(
                  "Download your saved cards in multiple formats",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                const SizedBox(height: 32),

                // Filter Section
                Text(
                  "Filter by Organization Type (Optional)",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _filterOptions
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFilter = value;
                        });
                      }
                    },
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                const SizedBox(height: 32),

                // Export Cards
                Text(
                  "Export Format",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // PDF Export Card
                _buildExportActionCard(
                  context,
                  title: 'Export to PDF',
                  description: 'Professional PDF with formatted table',
                  icon: Icons.picture_as_pdf,
                  colors: [
                    Colors.indigo.shade400,
                    Colors.purple.shade400,
                  ],
                  onTap: () => _handlePdfExport(),
                  delay: 0.ms,
                ),
                const SizedBox(height: 16),

                // Excel Export Card
                _buildExportActionCard(
                  context,
                  title: 'Export to Excel',
                  description: 'Excel spreadsheet with headers and styling',
                  icon: Icons.table_chart,
                  colors: [
                    Colors.green.shade400,
                    Colors.teal.shade400,
                  ],
                  onTap: () => _handleExcelExport(),
                  delay: 100.ms,
                ),
                const SizedBox(height: 16),

                // CSV Export Card
                _buildExportActionCard(
                  context,
                  title: 'Export to CSV',
                  description: 'Lightweight CSV format for spreadsheet apps',
                  icon: Icons.description,
                  colors: [
                    Colors.orange.shade400,
                    Colors.red.shade400,
                  ],
                  onTap: () => _handleCsvExport(),
                  delay: 200.ms,
                ),
                const SizedBox(height: 32),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Files are saved to your device\'s Downloads folder and can be shared via email, cloud storage, or other apps.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ),

        // Loading overlay
        if (_isExporting)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Generating export...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExportActionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    return GestureDetector(
      onTap: _isExporting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().scale(delay: delay, duration: 400.ms);
  }

  Future<void> _handlePdfExport() async {
    await _performExport('pdf');
  }

  Future<void> _handleExcelExport() async {
    await _performExport('excel');
  }

  Future<void> _handleCsvExport() async {
    await _performExport('csv');
  }

  Future<void> _performExport(String format) async {
    try {
      setState(() => _isExporting = true);

      // Load local cards
      final db = LocalDatabaseService();
      final cards = await db.getCards();

      if (!mounted) return;

      if (cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cards to export'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isExporting = false);
        return;
      }

      final exportService = ExportService();
      final filterType =
          _selectedFilter == "All" ? null : _selectedFilter;
      String filePath;

      switch (format) {
        case 'pdf':
          filePath = await exportService.exportToPdf(cards,
              filterType: filterType);
          break;
        case 'excel':
          filePath = await exportService.exportToXls(cards,
              filterType: filterType);
          break;
        case 'csv':
          filePath = await exportService.exportToCsv(cards,
              filterType: filterType);
          break;
        default:
          throw Exception('Unknown format');
      }

      if (!mounted) return;

      setState(() => _isExporting = false);

      // Show success snackbar with share option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Export successful!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'SHARE',
            textColor: Colors.white,
            onPressed: () async {
              try {
                await exportService.shareFile(filePath);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error sharing: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
