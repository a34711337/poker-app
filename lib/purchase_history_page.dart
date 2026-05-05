import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PurchaseHistoryPage extends StatelessWidget {
  const PurchaseHistoryPage({super.key});

  String _planName(String productId, String planType) {
    final clean = productId.toLowerCase();

    if (planType == 'host' || clean.contains('hostpro')) {
      return 'Host Pro';
    }

    if (planType == 'stats' || clean.contains('statspro')) {
      return 'Stats Pro';
    }

    return 'Subscription';
  }

  IconData _planIcon(String productId, String planType) {
    final clean = productId.toLowerCase();

    if (planType == 'host' || clean.contains('hostpro')) {
      return Icons.table_bar_outlined;
    }

    if (planType == 'stats' || clean.contains('statspro')) {
      return Icons.bar_chart_rounded;
    }

    return Icons.receipt_long_outlined;
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'No expiry';

    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');

    return '$y/$m/$d $h:$min';
  }

  int _daysLeft(DateTime? date) {
    if (date == null) return 0;
    final diff = date.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: true,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Purchase History',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('apple_subscriptions')
              .where('ownerUid', isEqualTo: uid)
              .orderBy('expiresAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No purchase history',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                final productId = (data['productId'] ?? '').toString();
                final planType = (data['planType'] ?? '').toString();
                final isActive = data['isActive'] == true;
                final source = (data['source'] ?? 'Apple').toString();
                final environment = (data['environment'] ?? '').toString();

                final expiresAt =
                    (data['expiresAt'] as Timestamp?)?.toDate();

                final planName = _planName(productId, planType);
                final icon = _planIcon(productId, planType);
                final daysLeft = _daysLeft(expiresAt);

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF2E7D32)
                          : Colors.black12,
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFF1F1F1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            icon,
                            color: isActive
                                ? const Color(0xFF2E7D32)
                                : Colors.black45,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                planName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Expires: ${_dateText(expiresAt)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                environment.isEmpty
                                    ? source
                                    : '$source • $environment',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Expired',
                                style: TextStyle(
                                  color: isActive
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 8),
                              Text(
                                '$daysLeft day(s) left',
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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