import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/logger.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ScanHistoryItem> _scans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      _scans = await HistoryDatabase.instance.getAllScans();
    } catch (e) {
      appLogger.e('Error loading history', e);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteScan(int id) async {
    await HistoryDatabase.instance.deleteScan(id);
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    await HistoryDatabase.instance.clearHistory();
    _loadHistory();
  }

  Color _getResultColor(String result) {
    switch (result) {
      case 'DEEPFAKE':
      case 'PHISHING':
        return Colors.red;
      case 'AUTHENTIC':
      case 'LEGITIMATE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getResultIcon(String type) {
    switch (type) {
      case 'deepfake':
        return Icons.face;
      case 'phishing':
        return Icons.link;
      default:
        return Icons.security;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_scans.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_scans.length} scans', style: TextStyle(color: Colors.grey.shade600)),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _scans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No scan history yet'),
                          Text('Your scans will appear here', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _scans.length,
                      itemBuilder: (context, index) {
                        final scan = _scans[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getResultColor(scan.result).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_getResultIcon(scan.type), color: _getResultColor(scan.result)),
                            ),
                            title: Text(
                              scan.type.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getResultColor(scan.result),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  scan.content.length > 40 ? '${scan.content.substring(0, 40)}...' : scan.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(_formatDate(scan.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    const Spacer(),
                                    Text('${(scan.confidence * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: _getResultColor(scan.result))),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteScan(scan.id),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
