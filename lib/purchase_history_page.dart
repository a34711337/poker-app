import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

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
          title: Text(
            tr(
              context,
              'Purchase History',
              zhTw: '購買紀錄',
              zhCn: '购买记录',
              ko: '구매 기록',
              ja: '購入履歴',
              de: 'Kaufverlauf',
              fr: 'Historique des achats',
              ar: 'سجل المشتريات',
              ru: 'История покупок',
              trk: 'Satın alma geçmişi',
              es: 'Historial de compras',
              it: 'Cronologia acquisti',
              pl: 'Historia zakupów',
              pt: 'Histórico de compras',
              th: 'ประวัติการซื้อ',
              id: 'Riwayat pembelian',
              hi: 'खरीद इतिहास',
              bn: 'ক্রয়ের ইতিহাস',
            ),
            style: const TextStyle(
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
              return Center(
                child: Text(
                  tr(
                    context,
                    'No purchase history',
                    zhTw: '尚無購買紀錄',
                    zhCn: '暂无购买记录',
                    ko: '구매 기록이 없습니다',
                    ja: '購入履歴がありません',
                    de: 'Keine Kaufhistorie',
                    fr: 'Aucun historique d’achat',
                    ar: 'لا يوجد سجل مشتريات',
                    ru: 'История покупок отсутствует',
                    trk: 'Satın alma geçmişi yok',
                    es: 'No hay historial de compras',
                    it: 'Nessuna cronologia acquisti',
                    pl: 'Brak historii zakupów',
                    pt: 'Nenhum histórico de compras',
                    th: 'ไม่มีประวัติการซื้อ',
                    id: 'Belum ada riwayat pembelian',
                    hi: 'कोई खरीद इतिहास नहीं है',
                    bn: 'কোনো ক্রয়ের ইতিহাস নেই',
                  ),
                  style: const TextStyle(
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
                        color: Colors.black.withValues(alpha: 0.06),
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
                                '${tr(
                                  context,
                                  'Expires',
                                  zhTw: '到期時間',
                                  zhCn: '到期时间',
                                  ko: '만료일',
                                  ja: '有効期限',
                                  de: 'Ablauf',
                                  fr: 'Expire le',
                                  ar: 'تاريخ الانتهاء',
                                  ru: 'Истекает',
                                  trk: 'Bitiş',
                                  es: 'Expira',
                                  it: 'Scade',
                                  pl: 'Wygasa',
                                  pt: 'Expira em',
                                  th: 'หมดอายุ',
                                  id: 'Kedaluwarsa',
                                  hi: 'समाप्ति',
                                  bn: 'মেয়াদ শেষ',
                                )}: ${_dateText(expiresAt)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
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
                                isActive
                                    ? tr(
                                        context,
                                        'Active',
                                        zhTw: '使用中',
                                        zhCn: '使用中',
                                        ko: '사용 중',
                                        ja: '有効',
                                        de: 'Aktiv',
                                        fr: 'Actif',
                                        ar: 'نشط',
                                        ru: 'Активно',
                                        trk: 'Aktif',
                                        es: 'Activo',
                                        it: 'Attivo',
                                        pl: 'Aktywny',
                                        pt: 'Ativo',
                                        th: 'ใช้งานอยู่',
                                        id: 'Aktif',
                                        hi: 'सक्रिय',
                                        bn: 'সক্রিয়',
                                      )
                                    : tr(
                                        context,
                                        'Expired',
                                        zhTw: '已過期',
                                        zhCn: '已过期',
                                        ko: '만료됨',
                                        ja: '期限切れ',
                                        de: 'Abgelaufen',
                                        fr: 'Expiré',
                                        ar: 'منتهي',
                                        ru: 'Истекло',
                                        trk: 'Süresi doldu',
                                        es: 'Expirado',
                                        it: 'Scaduto',
                                        pl: 'Wygasło',
                                        pt: 'Expirado',
                                        th: 'หมดอายุ',
                                        id: 'Kedaluwarsa',
                                        hi: 'समाप्त',
                                        bn: 'মেয়াদোত্তীর্ণ',
                                      ),
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF2E7D32) : Colors.red,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            if (isActive) ...[
                              const SizedBox(height: 8),
                              Text(
                                '$daysLeft ${tr(
                                  context,
                                  'day(s) left',
                                  zhTw: '天剩餘',
                                  zhCn: '天剩余',
                                  ko: '일 남음',
                                  ja: '日残り',
                                  de: 'Tage übrig',
                                  fr: 'jours restants',
                                  ar: 'يوم متبقي',
                                  ru: 'дн. осталось',
                                  trk: 'gün kaldı',
                                  es: 'días restantes',
                                  it: 'giorni rimasti',
                                  pl: 'dni pozostało',
                                  pt: 'dias restantes',
                                  th: 'วันคงเหลือ',
                                  id: 'hari tersisa',
                                  hi: 'दिन शेष',
                                  bn: 'দিন বাকি',
                                )}',
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