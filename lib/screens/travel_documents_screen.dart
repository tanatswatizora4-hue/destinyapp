import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class TravelDocumentsScreen extends StatefulWidget {
  final int userId;
  const TravelDocumentsScreen({super.key, required this.userId});

  @override
  State<TravelDocumentsScreen> createState() => _TravelDocumentsScreenState();
}

class _TravelDocumentsScreenState extends State<TravelDocumentsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  void _fetchDocuments() {
    _documentsFuture = _apiService.getTravelDocuments(widget.userId);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $url')),
        );
      }
    }
  }

  Future<void> _refreshDocuments() async {
    setState(() {
      _fetchDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDocuments,
        color: AppTheme.primary,
        child: FutureBuilder<List<dynamic>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('No travel documents available at the moment.'));
            }

            final documents = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return _buildDocumentCard(doc);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.description, color: AppTheme.primary),
        title: Text(doc['title'],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(doc['notes'] ?? 'No notes available.'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _launchUrl(doc['doc_url']),
      ),
    );
  }
}
