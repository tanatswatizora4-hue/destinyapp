import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/payment_intent.dart';
import 'package:destiny/repositories/payment_commerce_repository.dart';
import 'package:destiny/services/payment_api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Operational payment visibility inside existing /staff-ops.
class StaffPaymentsTab extends StatefulWidget {
  const StaffPaymentsTab({super.key});

  @override
  State<StaffPaymentsTab> createState() => _StaffPaymentsTabState();
}

class _StaffPaymentsTabState extends State<StaffPaymentsTab> {
  final PaymentCommerceRepository _repo = PaymentCommerceRepository();
  bool _loading = true;
  Object? _error;
  List<PaymentIntent> _intents = const [];
  StaffPaymentDetail? _detail;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.staffListPayments();
      if (!mounted) return;
      setState(() {
        _intents = list;
        _loading = false;
      });
      final selected = _detail?.intent.id;
      if (selected != null) {
        await _open(selected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _open(String id) async {
    try {
      final detail = await _repo.staffGetPayment(id);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.accent),
      );
    }
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    try {
      await op();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.accent),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error is PaymentApiException
                  ? (_error as PaymentApiException).message
                  : 'Unable to load payments: $_error',
            ),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final list = ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _intents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = _intents[i];
            final selected = _detail?.intent.id == p.id;
            return ListTile(
              selected: selected,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.border,
                ),
              ),
              title: Text(
                '${p.grossAmount.toStringAsFixed(2)} ${p.currency} · ${p.paymentStatus}',
              ),
              subtitle: Text(
                '${p.provider} · booking ${p.bookingId.substring(0, 8)}…',
              ),
              trailing: Text(p.settlementStatus),
              onTap: () => _open(p.id),
            );
          },
        );

        final detail = _detail == null
            ? const Center(child: Text('Select a payment'))
            : _PaymentDetail(
                detail: _detail!,
                busy: _busy,
                onRefund: () {
                  final id = _detail!.intent.id;
                  _run(() async {
                    final refund = await _repo.staffRequestRefund(
                      paymentIntentId: id,
                      reason: 'Staff ops refund',
                    );
                    await _repo.staffProcessRefund(refund.id);
                  });
                },
                onReconcile: (status) {
                  _run(() => _repo.staffReconcile(
                        paymentIntentId: _detail!.intent.id,
                        settlementStatus: status,
                      ));
                },
              );

        if (!wide) {
          return Column(
            children: [
              Expanded(child: list),
              const Divider(height: 1),
              SizedBox(height: 320, child: detail),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 380, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

class _PaymentDetail extends StatelessWidget {
  final StaffPaymentDetail detail;
  final bool busy;
  final VoidCallback onRefund;
  final void Function(String status) onReconcile;

  const _PaymentDetail({
    required this.detail,
    required this.busy,
    required this.onRefund,
    required this.onReconcile,
  });

  @override
  Widget build(BuildContext context) {
    final p = detail.intent;
    final money = NumberFormat.currency(locale: 'en_US', symbol: '');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Payment', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Status: ${p.paymentStatus}'),
        Text('Settlement: ${p.settlementStatus}'),
        Text('Provider: ${p.provider}${p.isMock ? ' (mock / QA)' : ''}'),
        Text('Reference: ${p.providerReference ?? '—'}'),
        Text('Gross: ${money.format(p.grossAmount)} ${p.currency}'),
        Text('Platform fee: ${money.format(p.platformFee)} ${p.currency}'),
        Text('Processor fee: ${money.format(p.providerFee)} ${p.currency}'),
        Text('Merchant net: ${money.format(p.merchantNet)} ${p.currency}'),
        Text('Booking: ${detail.booking['item_name'] ?? p.bookingId}'),
        Text('Booking status: ${detail.booking['status'] ?? '—'}'),
        Text('Customer: ${detail.booking['customer_user_id'] ?? '—'}'),
        if (p.createdAt != null)
          Text('Created: ${DateFormat.yMMMd().add_jm().format(p.createdAt!.toLocal())}'),
        const SizedBox(height: 16),
        Text('Ledger', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (detail.ledger.isEmpty) const Text('No ledger entries yet.'),
        ...detail.ledger.map(
          (e) => Text(
            '${e.createdAt ?? ''}  ${e.direction} ${e.account} ${money.format(e.amount)} ${e.currency} (${e.entryType})',
          ),
        ),
        const SizedBox(height: 16),
        Text('Refunds', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (detail.refunds.isEmpty) const Text('No refunds.'),
        ...detail.refunds.map(
          (r) => Text(
            '${r.status} ${money.format(r.amount)} ${r.currency} · ${r.reason}',
          ),
        ),
        const SizedBox(height: 16),
        Text('Events', style: Theme.of(context).textTheme.titleMedium),
        ...detail.events.take(12).map(
              (e) => Text('${e['created_at'] ?? ''}  ${e['event_type']}'),
            ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy || !p.isSucceeded ? null : onRefund,
              child: const Text('Request + process refund (mock)'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => onReconcile('reconciled'),
              child: const Text('Mark reconciled'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => onReconcile('discrepancy'),
              child: const Text('Flag discrepancy'),
            ),
          ],
        ),
      ],
    );
  }
}
