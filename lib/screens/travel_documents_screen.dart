import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/travel_document.dart';
import 'package:destiny/repositories/travel_documents_repository.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// M5A private travel documents — Supabase private bucket via customer-api.
/// Never uses public destiny-media URLs.
class TravelDocumentsScreen extends StatefulWidget {
  const TravelDocumentsScreen({super.key});

  @override
  State<TravelDocumentsScreen> createState() => _TravelDocumentsScreenState();
}

class _TravelDocumentsScreenState extends State<TravelDocumentsScreen> {
  final _repo = TravelDocumentsRepository();
  final _picker = ImagePicker();
  late Future<List<TravelDocument>> _future;
  bool _uploading = false;

  static const _types = <String, String>{
    'passport': 'Passport',
    'visa': 'Visa',
    'national_id': 'National ID',
    'residence_permit': 'Residence permit',
    'vaccination_certificate': 'Vaccination / travel certificate',
    'other': 'Other travel document',
  };

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  void _reload() {
    setState(() => _future = _repo.list());
  }

  Future<void> _open(TravelDocument doc) async {
    try {
      final access = await _repo.open(doc.id);
      final uri = Uri.parse(access.signedUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open secure document link')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open document: $e')),
      );
    }
  }

  Future<void> _delete(TravelDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content:
            Text('Remove “${doc.displayName}” from your secure Travel Docs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(doc.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove document: $e')),
      );
    }
  }

  Future<void> _upload() async {
    final pickedType = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _types.entries
              .map(
                (e) => ListTile(
                  title: Text(e.value),
                  onTap: () => Navigator.pop(ctx, e.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (pickedType == null) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 3500,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that file')),
      );
      return;
    }

    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';

    setState(() => _uploading = true);
    try {
      await _repo.upload(
        documentType: pickedType,
        displayName: file.name,
        mimeType: mime,
        bytes: bytes,
      );
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded securely')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        backgroundColor: AppTheme.accent,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_uploading ? 'Uploading…' : 'Upload'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        color: AppTheme.primary,
        child: FutureBuilder<List<TravelDocument>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load travel documents.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            final documents = snapshot.data ?? const [];
            if (documents.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(
                    Icons.folder_shared_outlined,
                    size: 48,
                    color: AppTheme.navy,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No private travel documents yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Upload a passport, visa, or ID securely. Files are private to your Destiny account — never published to marketing media.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = documents[index];
                return Material(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      doc.mimeType.contains('pdf')
                          ? Icons.picture_as_pdf_outlined
                          : Icons.badge_outlined,
                      color: AppTheme.navy,
                    ),
                    title: Text(
                      doc.displayName.isEmpty ? doc.typeLabel : doc.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        doc.typeLabel,
                        if (doc.expiryDate != null) 'Expires ${doc.expiryDate}',
                        doc.verificationStatus.replaceAll('_', ' '),
                        if (doc.createdAt != null)
                          'Uploaded ${doc.createdAt!.toLocal().toString().split('.').first}',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'open') _open(doc);
                        if (v == 'delete') _delete(doc);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'open',
                          child: Text('View securely'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Remove')),
                      ],
                    ),
                    onTap: () => _open(doc),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
