import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/repositories/customer_commerce_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Flight / trip enquiries owned by the signed-in Firebase user (M3A).
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final EnquiryRepository _enquiries = EnquiryRepository();
  late Future<List<CustomerEnquiry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CustomerEnquiry>> _load() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Sign in required');
    }
    final all = await _enquiries.listMine();
    return all.where((e) => e.kind == 'flight').toList(growable: false);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _closeEnquiry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close enquiry'),
        content: const Text(
          'Close this flight enquiry? Destiny will stop following up on it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _enquiries.close(enquiryId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry closed.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to close enquiry: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primary,
        child: FutureBuilder<List<CustomerEnquiry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Unable to load trip enquiries: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Your flight enquiries will appear here after you submit them.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final items = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildCard(items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(CustomerEnquiry enquiry) {
    final p = enquiry.payload;
    final origin = p['origin']?.toString() ?? '';
    final destination = p['destination']?.toString() ?? '';
    final mid = (p['mid_places'] is List)
        ? (p['mid_places'] as List).map((e) => e.toString()).join(', ')
        : '';
    final travelers = p['num_travelers']?.toString() ?? '1';
    final departure = p['departure_date']?.toString() ?? '';
    final ret = p['return_date']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$origin → $destination',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (mid.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Via: $mid',
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 8),
            Text('Travellers: $travelers'),
            if (departure.isNotEmpty) Text('Departure: $departure'),
            if (ret.isNotEmpty) Text('Return: $ret'),
            const SizedBox(height: 8),
            Chip(label: Text(enquiry.statusLabel)),
            if (enquiry.customerResponseNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(enquiry.customerResponseNote),
            ],
            const SizedBox(height: 4),
            const Text(
              'Enquiry only — not a confirmed ticket purchase.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            if (enquiry.status == 'received' ||
                enquiry.status == 'in_review') ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _closeEnquiry(enquiry.id),
                  child: const Text('Close enquiry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
