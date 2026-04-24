import 'package:universal_html/html.dart' as html;
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:in_app_purchase/in_app_purchase.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PokerReservationApp());
}

class PokerReservationApp extends StatelessWidget {
  const PokerReservationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Table Reservation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<UserSession?> _loadSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
  
    await ensureUserProfile(user);
  
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();
    if (data == null) return null;
  
    final name =
        (data['displayName'] ?? user.displayName ?? user.email ?? 'User')
            .toString();

    final roleText = (data['role'] ?? 'player').toString();
    final role = roleText == 'host' ? UserRole.host : UserRole.player;
  
    return UserSession(
      name: name,
      shortName: (data['shortName'] ?? name).toString(),
      role: role,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<UserSession?>(
          future: _loadSession(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (sessionSnapshot.hasError || sessionSnapshot.data == null) {
              return const LoginPage();
            }

            return TableListPage(session: sessionSnapshot.data!);
          },
        );
      },
    );
  }
}

enum UserRole { host, player }
const String superAdminEmail = 'a0980162600@gmail.com';

const Set<String> approvedHostEmails = {
  'yourmail1@gmail.com',
  'yourmail2@gmail.com',
  'yourmail3@gmail.com',
};
const String appVersion = '2026-04-21-01';

const String kCreateHostCheckoutUrl =
    'https://us-central1-poker-scheduler-fd8c7.cloudfunctions.net/createHostCheckoutSession';

const String kCreateStatsCheckoutUrl =
    'https://us-central1-poker-scheduler-fd8c7.cloudfunctions.net/createStatsCheckoutSession';

const String kCreateBundleCheckoutUrl =
    'https://us-central1-poker-scheduler-fd8c7.cloudfunctions.net/createBundleCheckoutSession';

const String kAppleHostProProductId =
    'com.pokerscheduler.hostpro.monthly';

const String kAppleStatsProProductId =
    'com.pokerscheduler.statspro.monthly';


mixin AppVersionChecker<T extends StatefulWidget> on State<T> {

  Timer? versionTimer;

  bool isCheckingVersion = false;

  bool hasNewVersion = false;


  void startVersionCheck() {

    _checkForNewVersion();

    versionTimer = Timer.periodic(

      const Duration(seconds: 60),

      (_) => _checkForNewVersion(),

    );

  }


  void stopVersionCheck() {

    versionTimer?.cancel();

  }


  Future<void> _checkForNewVersion() async {

    if (!kIsWeb) return;

    if (isCheckingVersion) return;


    isCheckingVersion = true;


    try {

      final uri = Uri.parse(

        '/version.json?t=${DateTime.now().millisecondsSinceEpoch}',

      );


      final response = await http.get(

        uri,

        headers: {

          'Cache-Control': 'no-cache',

          'Pragma': 'no-cache',

        },

      );


      if (response.statusCode != 200) return;


      final Map<String, dynamic> data =

          jsonDecode(response.body) as Map<String, dynamic>;


      final latestVersion = (data['version'] ?? '').toString().trim();


      if (latestVersion.isEmpty) return;

      if (!mounted) return;


      final shouldShowUpdate = latestVersion != appVersion;


      if (hasNewVersion != shouldShowUpdate) {

        setState(() {

          hasNewVersion = shouldShowUpdate;

        });

      }

    } catch (_) {

      // ignore

    } finally {

      isCheckingVersion = false;

    }

  }


  void forceRefreshWebPage() {

    if (!kIsWeb) return;


    setState(() {

      hasNewVersion = false;

    });


    final refreshUrl = Uri.base.replace(

      queryParameters: {

        ...Uri.base.queryParameters,

        'update': DateTime.now().millisecondsSinceEpoch.toString(),

      },

    ).toString();


    html.window.location.assign(refreshUrl);

  }

}

String buildShortName(String firstName, String lastName) {
  final f = firstName.trim();
  final l = lastName.trim();

  if (f.isEmpty) return 'User';
  if (l.isEmpty) return f;

  return '$f ${l[0].toUpperCase()}';
}

const List<String> kVirtualAvatarIcons = [
  'person',
  'sports_esports',
  'casino',
  'star',
  'favorite',
  'flash_on',
  'local_fire_department',
  'pets',
];

const List<int> kVirtualAvatarColors = [
  0xFF2563EB,
  0xFF7C3AED,
  0xFFDB2777,
  0xFFEA580C,
  0xFF16A34A,
  0xFF0891B2,
  0xFF4F46E5,
  0xFFB45309,
];

IconData virtualAvatarIconData(String key) {
  switch (key.trim()) {
    case 'sports_esports':
      return Icons.sports_esports;
    case 'casino':
      return Icons.casino;
    case 'star':
      return Icons.star;
    case 'favorite':
      return Icons.favorite;
    case 'flash_on':
      return Icons.flash_on;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'pets':
      return Icons.pets;
    case 'person':
    default:
      return Icons.person;
  }
}

Widget buildAppAvatar({
  required double radius,
  required AvatarSnapshot avatar,
  String? displayName,
  double iconSize = 20,
  double textSize = 18,
}) {
  final cleanPhotoUrl = (avatar.photoUrl ?? '').trim();
  final cleanName = (displayName ?? '').trim();

  if (avatar.avatarType == 'virtual') {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(avatar.avatarBgColor),
      child: Icon(
        virtualAvatarIconData(avatar.avatarIcon),
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  if (cleanPhotoUrl.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(cleanPhotoUrl),
    );
  }

  final fallbackText = cleanName.isEmpty
      ? '?'
      : cleanName.characters.first.toUpperCase();

  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE5E7EB),
    child: Text(
      fallbackText,
      style: TextStyle(
        fontSize: textSize,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF374151),
      ),
    ),
  );
}

Map<String, dynamic> resolveAvatarFieldsFromMap(Map<String, dynamic> data) {
  final avatarType =
      (data['avatarType'] ?? 'photo').toString().trim().isEmpty
          ? 'photo'
          : (data['avatarType'] ?? 'photo').toString().trim();

  final avatarIcon =
      (data['avatarIcon'] ?? 'person').toString().trim().isEmpty
          ? 'person'
          : (data['avatarIcon'] ?? 'person').toString().trim();

  final avatarBgColor = data['avatarBgColor'] is int
      ? data['avatarBgColor'] as int
      : 0xFF2563EB;

  final photoUrl = (data['photoUrl'] ?? '').toString().trim();

  return {
    'avatarType': avatarType,
    'avatarIcon': avatarIcon,
    'avatarBgColor': avatarBgColor,
    'photoUrl': photoUrl,
  };
}

class AvatarSnapshot {
  final String avatarType;
  final String avatarIcon;
  final int avatarBgColor;
  final String? photoUrl;

  const AvatarSnapshot({
    required this.avatarType,
    required this.avatarIcon,
    required this.avatarBgColor,
    required this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'avatarType': avatarType,
      'avatarIcon': avatarIcon,
      'avatarBgColor': avatarBgColor,
      'photoUrl': photoUrl,
    };
  }

  factory AvatarSnapshot.fromMap(Map<String, dynamic>? map) {
    final data = map ?? <String, dynamic>{};

    final resolvedAvatarType =
        (data['avatarType'] ?? 'photo').toString().trim().isEmpty
            ? 'photo'
            : (data['avatarType'] ?? 'photo').toString().trim();

    final resolvedAvatarIcon =
        (data['avatarIcon'] ?? 'person').toString().trim().isEmpty
            ? 'person'
            : (data['avatarIcon'] ?? 'person').toString().trim();

    final resolvedAvatarBgColor = data['avatarBgColor'] is int
        ? data['avatarBgColor'] as int
        : 0xFF2563EB;

    final resolvedPhotoUrl =
        (data['photoUrl'] ?? '').toString().trim().isEmpty
            ? null
            : (data['photoUrl'] ?? '').toString().trim();

    return AvatarSnapshot(
      avatarType: resolvedAvatarType,
      avatarIcon: resolvedAvatarIcon,
      avatarBgColor: resolvedAvatarBgColor,
      photoUrl: resolvedPhotoUrl,
    );
  }
}

AvatarSnapshot resolveAvatarSnapshotFromMap(Map<String, dynamic> data) {
  return AvatarSnapshot.fromMap({
    'avatarType': data['avatarType'],
    'avatarIcon': data['avatarIcon'],
    'avatarBgColor': data['avatarBgColor'],
    'photoUrl': data['photoUrl'],
  });
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
       composing: TextRange.empty,
    );
  }
}

Map<String, dynamic> buildUserProfileMap({
  required String displayName,
  required String lastName,
  required String email,
  required String playerId,
  required String roleText,
  String? photoUrl,
  String avatarType = 'photo',
  String avatarIcon = 'person',
  int avatarBgColor = 0xFF2563EB,
  List<dynamic>? grantedHostIds,
  List<dynamic>? blockedUids,
  bool? isActive,
  dynamic createdAt,
  bool includeCreatedAt = true,
}) {
  final cleanDisplayName = displayName.trim();
  final cleanLastName = lastName.trim();
  final cleanEmail = email.trim();
  final cleanPlayerId = playerId.trim();

  final shortName = buildShortName(cleanDisplayName, cleanLastName);

  final map = <String, dynamic>{
    'displayName': cleanDisplayName,
    'displayNameLower': cleanDisplayName.toLowerCase(),
    'lastName': cleanLastName,
    'shortName': shortName,
    'shortNameLower': shortName.toLowerCase(),
    'email': cleanEmail,
    'emailLower': cleanEmail.toLowerCase(),
    'role': roleText,
    'playerId': cleanPlayerId,
    'playerIdLower': cleanPlayerId.toLowerCase(),
    'grantedHostIds': grantedHostIds ?? <String>[],
    'blockedUids': blockedUids ?? <String>[],
    'photoUrl': photoUrl,
    'avatarType': avatarType,
    'avatarIcon': avatarIcon,
    'avatarBgColor': avatarBgColor,
    'isActive': isActive ?? true,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  if (includeCreatedAt) {
    map['createdAt'] = createdAt ?? FieldValue.serverTimestamp();
  }

  return map;
}

String generatePlayerId() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = math.Random.secure();
  return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
}

Future<String> generateUniquePlayerId() async {
  while (true) {
    final newId = generatePlayerId();

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('playerId', isEqualTo: newId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return newId;
    }
  }
}

Future<void> ensureUserProfile(User user) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final userDoc = await userRef.get();

  final defaultName =
      (user.displayName != null && user.displayName!.trim().isNotEmpty)
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'User');

  if (!userDoc.exists) {
    final newPlayerId = await generateUniquePlayerId();

    await userRef.set(
      buildUserProfileMap(
        displayName: defaultName,
        lastName: '',
        email: user.email ?? '',
        playerId: newPlayerId,
        roleText: 'player',
        photoUrl: user.photoURL,
        grantedHostIds: <String>[],
        blockedUids: <String>[],
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
        includeCreatedAt: true,
      ),
    );
    return;
  }

  final data = userDoc.data() ?? {};

  String resolvedDisplayName =
      (data['displayName'] ?? '').toString().trim();
  if (resolvedDisplayName.isEmpty) {
    resolvedDisplayName = defaultName;
  }

  String resolvedLastName = (data['lastName'] ?? '').toString().trim();

  String resolvedEmail = (data['email'] ?? '').toString().trim();
  if (resolvedEmail.isEmpty) {
    resolvedEmail = user.email ?? '';
  }

  String resolvedRole = (data['role'] ?? '').toString().trim();
  if (resolvedRole.isEmpty) {
    resolvedRole = 'player';
  }

  final hostStatus = resolveHostSubscriptionStatusFromUserData(data);
  if (hostStatus.shouldDowngradeToPlayer) {
    resolvedRole = 'player';
  }

  String resolvedPlayerId = (data['playerId'] ?? '').toString().trim();
  if (resolvedPlayerId.isEmpty) {
    resolvedPlayerId = await generateUniquePlayerId();
  }

  final resolvedGrantedHostIds =
      List<dynamic>.from(data['grantedHostIds'] ?? <String>[]);
  final resolvedBlockedUids =
      List<dynamic>.from(data['blockedUids'] ?? <String>[]);

  final resolvedPhotoUrl = data.containsKey('photoUrl')
      ? data['photoUrl']
      : user.photoURL;

  final resolvedAvatarType =
      (data['avatarType'] ?? 'photo').toString().trim().isEmpty
          ? 'photo'
          : (data['avatarType'] ?? 'photo').toString().trim();

  final resolvedAvatarIcon =
      (data['avatarIcon'] ?? 'person').toString().trim().isEmpty
          ? 'person'
          : (data['avatarIcon'] ?? 'person').toString().trim();

  final resolvedAvatarBgColor = data['avatarBgColor'] is int
      ? data['avatarBgColor'] as int
      : 0xFF2563EB;

  final resolvedIsActive = data['isActive'] == false ? false : true;
  final resolvedCreatedAt = data['createdAt'];

  await userRef.set(
    buildUserProfileMap(
      displayName: resolvedDisplayName,
      lastName: resolvedLastName,
      email: resolvedEmail,
      playerId: resolvedPlayerId,
      roleText: resolvedRole,
      photoUrl: resolvedPhotoUrl?.toString(),
      avatarType: resolvedAvatarType,
      avatarIcon: resolvedAvatarIcon,
      avatarBgColor: resolvedAvatarBgColor,
      grantedHostIds: resolvedGrantedHostIds,
      blockedUids: resolvedBlockedUids,
      isActive: resolvedIsActive,
      createdAt: resolvedCreatedAt,
      includeCreatedAt: true,
    ),
    SetOptions(merge: true),
  );

  if (hostStatus.shouldDowngradeToPlayer) {
    await userRef.set({
      'hostDowngradedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

Future<String> saveUserProfileData({
  required User user,
  required String displayName,
  required String lastName,
  required UserRole role,
}) async {
  final cleanDisplayName = displayName.trim();
  final cleanLastName = lastName.trim();

  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);

  final existingDoc = await userRef.get();
  final existingData = existingDoc.data() ?? {};

  String playerId = (existingData['playerId'] ?? '').toString().trim();
  if (playerId.isEmpty) {
    playerId = await generateUniquePlayerId();
  }

  await user.updateDisplayName(cleanDisplayName);

  final shortName = buildShortName(cleanDisplayName, cleanLastName);

  await userRef.set(
    buildUserProfileMap(
      displayName: cleanDisplayName,
      lastName: cleanLastName,
      email: user.email ?? '',
      playerId: playerId,
      roleText: role == UserRole.host ? 'host' : 'player',
      photoUrl: (existingData['photoUrl'] ?? user.photoURL)?.toString(),
      avatarType: (existingData['avatarType'] ?? 'photo').toString(),
      avatarIcon: (existingData['avatarIcon'] ?? 'person').toString(),
      avatarBgColor: existingData['avatarBgColor'] is int
          ? existingData['avatarBgColor'] as int
          : 0xFF2563EB,
      grantedHostIds:
          List<dynamic>.from(existingData['grantedHostIds'] ?? <String>[]),
      blockedUids:
          List<dynamic>.from(existingData['blockedUids'] ?? <String>[]),
      isActive: existingData['isActive'] == false ? false : true,
      createdAt: existingData['createdAt'] ?? FieldValue.serverTimestamp(),
      includeCreatedAt: true,
    ),
    SetOptions(merge: true),
  );

  return shortName;
}

class UserSession {
  final String name;
  final String shortName;
  final UserRole role;

  const UserSession({
    required this.name,
    required this.shortName,
    required this.role,
  });
}

class HostSubscriptionStatus {
  final bool isHostRole;
  final bool isPaidActive;
  final bool isGracePeriod;
  final bool canCreateTable;
  final bool showRenewBanner;
  final bool shouldDowngradeToPlayer;
  final DateTime? expiresAt;
  final DateTime? graceEndsAt;

  const HostSubscriptionStatus({
    required this.isHostRole,
    required this.isPaidActive,
    required this.isGracePeriod,
    required this.canCreateTable,
    required this.showRenewBanner,
    required this.shouldDowngradeToPlayer,
    required this.expiresAt,
    required this.graceEndsAt,
  });

  const HostSubscriptionStatus.player()
      : isHostRole = false,
        isPaidActive = false,
        isGracePeriod = false,
        canCreateTable = false,
        showRenewBanner = false,
        shouldDowngradeToPlayer = false,
        expiresAt = null,
        graceEndsAt = null;
}

DateTime? firestoreDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }

  return null;
}

HostSubscriptionStatus resolveHostSubscriptionStatusFromUserData(
  Map<String, dynamic>? rawData,
) {
  final data = rawData ?? <String, dynamic>{};
  final role = (data['role'] ?? 'player').toString().trim();

  if (role != 'host') {
    return const HostSubscriptionStatus.player();
  }

  final expiresAt = firestoreDateTime(data['hostExpiresAt']);

  if (expiresAt == null) {
    return const HostSubscriptionStatus(
      isHostRole: true,
      isPaidActive: true,
      isGracePeriod: false,
      canCreateTable: true,
      showRenewBanner: false,
      shouldDowngradeToPlayer: false,
      expiresAt: null,
      graceEndsAt: null,
    );
  }

  final now = DateTime.now();
  final reminderStart = expiresAt.subtract(const Duration(days: 3));
  final graceEndsAt = expiresAt.add(const Duration(days: 14));

  if (now.isAfter(graceEndsAt)) {
    return HostSubscriptionStatus(
      isHostRole: false,
      isPaidActive: false,
      isGracePeriod: false,
      canCreateTable: false,
      showRenewBanner: false,
      shouldDowngradeToPlayer: true,
      expiresAt: expiresAt,
      graceEndsAt: graceEndsAt,
    );
  }

  if (!now.isAfter(expiresAt)) {
    return HostSubscriptionStatus(
      isHostRole: true,
      isPaidActive: true,
      isGracePeriod: false,
      canCreateTable: true,
      showRenewBanner: !now.isBefore(reminderStart),
      expiresAt: expiresAt,
      graceEndsAt: graceEndsAt,
      shouldDowngradeToPlayer: false,
    );
  }

  return HostSubscriptionStatus(
    isHostRole: true,
    isPaidActive: false,
    isGracePeriod: true,
    canCreateTable: false,
    showRenewBanner: true,
    shouldDowngradeToPlayer: false,
    expiresAt: expiresAt,
    graceEndsAt: graceEndsAt,
  );
}

Future<void> activateHostSubscriptionForUserUid(
  String uid, {
  int durationDays = 30,
}) async {
  final now = DateTime.now();
  final expiresAt = now.add(Duration(days: durationDays));

  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'role': 'host',
    'hostActivatedAt': Timestamp.fromDate(now),
    'hostLastPaidAt': Timestamp.fromDate(now),
    'hostExpiresAt': Timestamp.fromDate(expiresAt),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class StatsSubscriptionStatus {
  final bool isPaidActive;
  final DateTime? expiresAt;

  const StatsSubscriptionStatus({
    required this.isPaidActive,
    required this.expiresAt,
  });

  const StatsSubscriptionStatus.unpaid()
      : isPaidActive = false,
        expiresAt = null;
}

StatsSubscriptionStatus resolveStatsSubscriptionStatusFromUserData(
  Map<String, dynamic>? rawData,
) {
  final data = rawData ?? <String, dynamic>{};
  final expiresAt = firestoreDateTime(data['statsExpiresAt']);

  if (expiresAt == null) {
    return const StatsSubscriptionStatus.unpaid();
  }

  final now = DateTime.now();

  if (now.isAfter(expiresAt)) {
    return const StatsSubscriptionStatus.unpaid();
  }

  return StatsSubscriptionStatus(
    isPaidActive: true,
    expiresAt: expiresAt,
  );
}

Future<void> activateStatsSubscriptionForUserUid(
  String uid, {
  int durationDays = 30,
}) async {
  final now = DateTime.now();
  final expiresAt = now.add(Duration(days: durationDays));

  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'statsActivatedAt': Timestamp.fromDate(now),
    'statsLastPaidAt': Timestamp.fromDate(now),
    'statsExpiresAt': Timestamp.fromDate(expiresAt),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

enum ApplePurchaseType {
  host,
  stats,
  bundle,
}

bool get isAppleIapPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}

class AppleIapService {
  static Future<void> buy({
    required String productId,
    required ApplePurchaseType type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login again');
    }

    final iap = InAppPurchase.instance;
    final available = await iap.isAvailable();

    if (!available) {
      throw Exception('In-App Purchase is not available');
    }

    final productResponse = await iap.queryProductDetails({productId});

    if (productResponse.error != null) {
      throw Exception(productResponse.error!.message);
    }

    if (productResponse.productDetails.isEmpty) {
      throw Exception('Product not found: $productId');
    }

    final product = productResponse.productDetails.first;
    final purchaseParam = PurchaseParam(productDetails: product);

    final purchaseCompleter = Completer<void>();
    late StreamSubscription<List<PurchaseDetails>> subscription;

    subscription = iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != productId) continue;

          if (purchase.status == PurchaseStatus.pending) {
            continue;
          }

          if (purchase.status == PurchaseStatus.error) {
            if (!purchaseCompleter.isCompleted) {
              purchaseCompleter.completeError(
                Exception(purchase.error?.message ?? 'Purchase failed'),
              );
            }
            continue;
          }

          if (purchase.status == PurchaseStatus.canceled) {
            if (!purchaseCompleter.isCompleted) {
              purchaseCompleter.completeError(
                Exception('Purchase cancelled'),
              );
            }
            continue;
          }

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            if (type == ApplePurchaseType.host) {
              await activateHostSubscriptionForUserUid(user.uid);
            } else if (type == ApplePurchaseType.stats) {
              await activateStatsSubscriptionForUserUid(user.uid);
            } else if (type == ApplePurchaseType.bundle) {
              await activateHostSubscriptionForUserUid(user.uid);
              await activateStatsSubscriptionForUserUid(user.uid);
            }

            if (purchase.pendingCompletePurchase) {
              await iap.completePurchase(purchase);
            }

            if (!purchaseCompleter.isCompleted) {
              purchaseCompleter.complete();
            }
          }
        }
      },
      onError: (error) {
        if (!purchaseCompleter.isCompleted) {
          purchaseCompleter.completeError(error);
        }
      },
    );

    try {
      final started = await iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!started) {
        throw Exception('Failed to start purchase');
      }

      await purchaseCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Purchase timeout');
        },
      );
    } finally {
      await subscription.cancel();
    }
  }
}
class SeatReservation {
  String? playerName;
  String? playerLastName;
  String? playerShortName;
  String? playerUid;
  String? playerPhotoUrl;
  String? playerId;

  String? playerAvatarType;
  String? playerAvatarIcon;
  int? playerAvatarBgColor;

  String? reservedForName;
  String? reservedForShortName;
  String? reservedForUid;
  String? reservedForPlayerId;
  bool? reservedArrived;
  bool? arrived;

  SeatReservation({
    this.playerName,
    this.playerLastName,
    this.playerShortName,
    this.playerUid,
    this.playerPhotoUrl,
    this.playerId,
    this.playerAvatarType,
    this.playerAvatarIcon,
    this.playerAvatarBgColor,
    this.reservedForName,
    this.reservedForShortName,
    this.reservedForUid,
    this.reservedForPlayerId,
    this.reservedArrived,
    this.arrived,
  });

  bool get isOccupied =>
      playerUid != null ||
      (playerName != null && playerName!.trim().isNotEmpty);

  bool get isReserved =>
      !isOccupied &&
      (
        (reservedForName != null && reservedForName!.trim().isNotEmpty) ||
        (reservedForUid != null && reservedForUid!.trim().isNotEmpty) ||
        (reservedForPlayerId != null && reservedForPlayerId!.trim().isNotEmpty)
      );

  bool get isOpen => !isOccupied && !isReserved;

  Map<String, dynamic> toMap() {
    return {
      'playerName': playerName,
      'playerLastName': playerLastName,
      'playerShortName': playerShortName,
      'playerUid': playerUid,
      'playerPhotoUrl': playerPhotoUrl,
      'playerId': playerId,
      'playerAvatarType': playerAvatarType,
      'playerAvatarIcon': playerAvatarIcon,
      'playerAvatarBgColor': playerAvatarBgColor,
      'reservedForName': reservedForName,
      'reservedForShortName': reservedForShortName,
      'reservedForUid': reservedForUid,
      'reservedForPlayerId': reservedForPlayerId,
      'reservedArrived': reservedArrived,
      'arrived': arrived,
    };
  }

  factory SeatReservation.fromMap(Map<String, dynamic>? map) {
    final safeMap = map ?? <String, dynamic>{};

    return SeatReservation(
      playerName: safeMap['playerName'],
      playerLastName: safeMap['playerLastName'],
      playerShortName: safeMap['playerShortName'],
      playerUid: safeMap['playerUid'],
      playerPhotoUrl: safeMap['playerPhotoUrl'],
      playerId: safeMap['playerId'],
      playerAvatarType: (safeMap['playerAvatarType'] ?? '').toString(),
      playerAvatarIcon: (safeMap['playerAvatarIcon'] ?? '').toString(),
      playerAvatarBgColor: safeMap['playerAvatarBgColor'] is int
          ? safeMap['playerAvatarBgColor'] as int
          : null,
      reservedForName: safeMap['reservedForName'],
      reservedForShortName: safeMap['reservedForShortName'],
      reservedForUid: safeMap['reservedForUid'],
      reservedForPlayerId: safeMap['reservedForPlayerId'],
      reservedArrived: safeMap['reservedArrived'] == true,
      arrived: safeMap['arrived'] == true,
    );
  }
}

class FriendUser {
  final String uid;
  final String displayName;
  final String shortName;
  final String email;
  final String? photoUrl;
  final String playerId;

  const FriendUser({
    required this.uid,
    required this.displayName,
    required this.shortName,
    required this.email,
    required this.photoUrl,
    required this.playerId,
  });

  factory FriendUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return FriendUser(
      uid: doc.id,
      displayName: (data['displayName'] ?? '').toString(),
      shortName: (data['shortName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString().trim().isEmpty
          ? null
          : data['photoUrl'].toString().trim(),
      playerId: (data['playerId'] ?? '').toString(),
    );
  }
}

String buildDirectChatId(String uid1, String uid2) {
  final ids = [uid1.trim(), uid2.trim()]..sort();
  return '${ids[0]}_${ids[1]}';
}

Future<bool> isBlockedEitherWay({
  required String currentUid,
  required String otherUid,
}) async {
  if (currentUid.trim().isEmpty || otherUid.trim().isEmpty) {
    return true;
  }

  final usersRef = FirebaseFirestore.instance.collection('users');

  final currentDoc = await usersRef.doc(currentUid).get();
  final otherDoc = await usersRef.doc(otherUid).get();

  final currentData = currentDoc.data() ?? {};
  final otherData = otherDoc.data() ?? {};

  final currentBlocked = List<String>.from(currentData['blockedUids'] ?? []);
  final otherBlocked = List<String>.from(otherData['blockedUids'] ?? []);

  return currentBlocked.contains(otherUid) || otherBlocked.contains(currentUid);
}

Future<List<String>> loadBlockedChatIdsForCurrentUser(String currentUid) async {
  if (currentUid.trim().isEmpty) return [];

  final usersRef = FirebaseFirestore.instance.collection('users');
  final currentDoc = await usersRef.doc(currentUid).get();
  final currentData = currentDoc.data() ?? {};
  final currentBlocked = List<String>.from(currentData['blockedUids'] ?? []);

  final blockedChatIds = <String>[];

  for (final otherUid in currentBlocked) {
    if (otherUid.trim().isEmpty) continue;
    blockedChatIds.add(buildDirectChatId(currentUid, otherUid));
  }

  return blockedChatIds;
}

Future<void> sendFriendRequest({
  required FriendUser targetUser,
}) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw Exception('Not logged in');
  }

  if (currentUser.uid == targetUser.uid) {
    throw Exception('You cannot add yourself');
  }

  final currentUserDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();

  final currentData = currentUserDoc.data() ?? {};

  final currentBlocked = List<String>.from(currentData['blockedUids'] ?? []);

  if (currentBlocked.contains(targetUser.uid)) {
    throw Exception('This user is in your blacklist');
  }

  final targetUserDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(targetUser.uid)
      .get();

  final targetData = targetUserDoc.data() ?? {};
  final targetBlocked = List<String>.from(targetData['blockedUids'] ?? []);

  if (targetBlocked.contains(currentUser.uid)) {
    throw Exception('You cannot add this user');
  }

  final currentDisplayName =
      (currentData['displayName'] ?? currentUser.displayName ?? 'User')
          .toString()
          .trim();

  final currentShortName =
      (currentData['shortName'] ?? currentDisplayName).toString().trim();

  final currentPhotoUrl = (currentData['photoUrl'] ?? currentUser.photoURL)
      ?.toString()
      .trim();

  final requestId = buildDirectChatId(currentUser.uid, targetUser.uid);

  final requestRef = FirebaseFirestore.instance
      .collection('friend_requests')
      .doc(requestId);

  final duplicateQuery = await FirebaseFirestore.instance
      .collection('friend_requests')
      .where('fromUid', isEqualTo: currentUser.uid)
      .where('toUid', isEqualTo: targetUser.uid)
      .limit(1)
      .get();

  if (duplicateQuery.docs.isNotEmpty) {
    final data = duplicateQuery.docs.first.data();
    final status = (data['status'] ?? '').toString().trim();

    if (status == 'pending') {
      throw Exception('Friend request already sent');
    }

    if (status == 'accepted') {
      throw Exception('Already friends');
    }

    if (status == 'ignored') {
      throw Exception('Friend request already sent');
    }
  }

  await requestRef.set({
    'requestId': requestId,
    'fromUid': currentUser.uid,
    'toUid': targetUser.uid,
    'fromDisplayName': currentDisplayName,
    'fromShortName': currentShortName,
    'fromPhotoUrl': currentPhotoUrl,
    'toDisplayName': targetUser.displayName,
    'toShortName': targetUser.shortName,
    'toPhotoUrl': targetUser.photoUrl,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> acceptFriendRequest(Map<String, dynamic> requestData) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw Exception('Not logged in');
  }

  final fromUid = (requestData['fromUid'] ?? '').toString().trim();
  final toUid = (requestData['toUid'] ?? '').toString().trim();

  if (toUid != currentUser.uid) {
    throw Exception('Invalid request');
  }

  final chatId = buildDirectChatId(fromUid, toUid);

  final usersRef = FirebaseFirestore.instance.collection('users');
  final requestRef = FirebaseFirestore.instance
      .collection('friend_requests')
      .doc(chatId);
  final friendshipRef = FirebaseFirestore.instance
      .collection('friendships')
      .doc(chatId);
  final chatRef = FirebaseFirestore.instance
      .collection('direct_chats')
      .doc(chatId);

  final fromUserDoc = await usersRef.doc(fromUid).get();
  final toUserDoc = await usersRef.doc(toUid).get();

  final fromData = fromUserDoc.data() ?? {};
  final toData = toUserDoc.data() ?? {};

  await FirebaseFirestore.instance.runTransaction((tx) async {
    tx.set(friendshipRef, {
      'chatId': chatId,
      'memberUids': [fromUid, toUid],
      'userA': {
        'uid': fromUid,
        'displayName': (fromData['displayName'] ?? '').toString(),
        'shortName': (fromData['shortName'] ?? '').toString(),
        'photoUrl': (fromData['photoUrl'] ?? '').toString(),
        'avatarType': (fromData['avatarType'] ?? 'photo').toString(),
        'avatarIcon': (fromData['avatarIcon'] ?? 'person').toString(),
        'avatarBgColor': fromData['avatarBgColor'] is int
            ? fromData['avatarBgColor'] as int
            : 0xFF2563EB,
        'playerId': (fromData['playerId'] ?? '').toString(),
      },
      'userB': {
        'uid': toUid,
        'displayName': (toData['displayName'] ?? '').toString(),
        'shortName': (toData['shortName'] ?? '').toString(),
        'photoUrl': (toData['photoUrl'] ?? '').toString(),
        'avatarType': (toData['avatarType'] ?? 'photo').toString(),
        'avatarIcon': (toData['avatarIcon'] ?? 'person').toString(),
        'avatarBgColor': toData['avatarBgColor'] is int
            ? toData['avatarBgColor'] as int
            : 0xFF2563EB,
        'playerId': (toData['playerId'] ?? '').toString(),
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    tx.set(chatRef, {
      'chatId': chatId,
      'type': 'direct',
      'memberUids': [fromUid, toUid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderUid': '',
      'unreadCounts': {
        fromUid: 0,
        toUid: 0,
      },
    }, SetOptions(merge: true));

    tx.set(requestRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

Future<void> _setFriendRequestStatus({
  required String fromUid,
  required String toUid,
  required String status,
}) async {
  final requestId = buildDirectChatId(fromUid, toUid);

  await FirebaseFirestore.instance
      .collection('friend_requests')
      .doc(requestId)
      .set({
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> rejectFriendRequest(Map<String, dynamic> requestData) async {
  final fromUid = (requestData['fromUid'] ?? '').toString().trim();
  final toUid = (requestData['toUid'] ?? '').toString().trim();

  await _setFriendRequestStatus(
    fromUid: fromUid,
    toUid: toUid,
    status: 'rejected',
  );
}

Future<void> ignoreFriendRequest(Map<String, dynamic> requestData) async {
  final fromUid = (requestData['fromUid'] ?? '').toString().trim();
  final toUid = (requestData['toUid'] ?? '').toString().trim();

  await _setFriendRequestStatus(
    fromUid: fromUid,
    toUid: toUid,
    status: 'ignored',
  );
}

Future<void> deleteFriend({
  required String currentUid,
  required String otherUid,
}) async {
  final chatId = buildDirectChatId(currentUid, otherUid);

  final friendshipRef = FirebaseFirestore.instance
      .collection('friendships')
      .doc(chatId);

  final chatRef = FirebaseFirestore.instance
      .collection('direct_chats')
      .doc(chatId);

  final requestRef = FirebaseFirestore.instance
      .collection('friend_requests')
      .doc(chatId);

  final messagesSnap = await chatRef.collection('messages').get();

  final batch = FirebaseFirestore.instance.batch();

  for (final doc in messagesSnap.docs) {
    batch.delete(doc.reference);
  }

  batch.delete(chatRef);
  batch.delete(friendshipRef);
  batch.delete(requestRef);

  await batch.commit();
}

Future<void> blockUser({
  required String currentUid,
  required String targetUid,
}) async {
  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid);

  await userRef.set({
    'blockedUids': FieldValue.arrayUnion([targetUid]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await deleteFriend(
    currentUid: currentUid,
    otherUid: targetUid,
  );
}

Future<void> unblockUser({
  required String currentUid,
  required String targetUid,
}) async {
  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid);

  await userRef.set({
    'blockedUids': FieldValue.arrayRemove([targetUid]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> saveFriendNickname({
  required String chatId,
  required String currentUid,
  required String nickname,
}) async {
  await FirebaseFirestore.instance
      .collection('friendships')
      .doc(chatId)
      .set({
    'nicknames': {
      currentUid: nickname.trim(),
    },
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

String resolveFriendDisplayName({
  required Map<String, dynamic> friendshipData,
  required String currentUid,
}) {
  final userA = Map<String, dynamic>.from(friendshipData['userA'] ?? {});
  final userB = Map<String, dynamic>.from(friendshipData['userB'] ?? {});
  final nicknames = Map<String, dynamic>.from(friendshipData['nicknames'] ?? {});

  final otherUser =
      (userA['uid'] ?? '').toString() == currentUid ? userB : userA;

  final nickname = (nicknames[currentUid] ?? '').toString().trim();

  if (nickname.isNotEmpty) {
    return nickname;
  }

  return (otherUser['displayName'] ?? 'Friend').toString();
}

Map<String, dynamic> normalizeWaitingEntry(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return {
      'uid': (raw['uid'] ?? '').toString().trim(),
      'name': (raw['name'] ?? '').toString().trim(),
      'shortName': (raw['shortName'] ?? '').toString().trim(),
      'playerId': (raw['playerId'] ?? '').toString().trim(),
      'arrived': raw['arrived'] == true,
    };
  }

  if (raw is Map) {
    return {
      'uid': (raw['uid'] ?? '').toString().trim(),
      'name': (raw['name'] ?? '').toString().trim(),
      'shortName': (raw['shortName'] ?? '').toString().trim(),
      'playerId': (raw['playerId'] ?? '').toString().trim(),
      'arrived': raw['arrived'] == true,
    };
  }

  if (raw is String) {
    final name = raw.trim();
    return {
      'uid': '',
      'name': name,
      'shortName': name,
      'playerId': '',
      'arrived': false,
    };
  }

  return {
    'uid': '',
    'name': '',
    'shortName': '',
    'playerId': '',
    'arrived': false,
  };
}

List<Map<String, dynamic>> normalizeSeatMaps(dynamic rawSeats) {

  return List<dynamic>.from(rawSeats ?? []).map((seat) {

    if (seat is Map<String, dynamic>) {
      return Map<String, dynamic>.from(seat);
    }

    if (seat is Map) {
      return Map<String, dynamic>.from(seat);
    }

    if (seat is String) {
      return {
        'playerName': seat,
        'playerLastName': null,
        'playerShortName': seat,
        'playerUid': null,
        'playerPhotoUrl': null,
        'playerId': null,
        'playerAvatarType': null,
        'playerAvatarIcon': null,
        'playerAvatarBgColor': null,
        'reservedForName': null,
        'reservedForShortName': null,
        'reservedForUid': null,
        'reservedForPlayerId': null,
        'reservedArrived': null,
        'arrived': null,
      };
    }

    return {
      'playerName': null,
      'playerLastName': null,
      'playerShortName': null,
      'playerUid': null,
      'playerPhotoUrl': null,
      'playerId': null,
      'playerAvatarType': null,
      'playerAvatarIcon': null,
      'playerAvatarBgColor': null,
      'reservedForName': null,
      'reservedForShortName': null,
      'reservedForUid': null,
      'reservedForPlayerId': null,
      'reservedArrived': null,
      'arrived': null,
    };

  }).toList();

}


Map<String, dynamic> buildEmptySeatMap() {
  
  return {
    'playerName': null,
    'playerLastName': null,
    'playerShortName': null,
    'playerUid': null,
    'playerPhotoUrl': null,
    'playerId': null,
    'playerAvatarType': null,
    'playerAvatarIcon': null,
    'playerAvatarBgColor': null,
    'reservedForName': null,
    'reservedForShortName': null,
    'reservedForUid': null,
    'reservedForPlayerId': null,
    'reservedArrived': null,
    'arrived': null,
  };
  
}

Map<String, dynamic> buildOccupiedSeatMap({
  required String playerName,
  required String playerShortName,
  required String playerUid,
  required String playerId,
  String? playerPhotoUrl,
  String? playerLastName,
  String? playerAvatarType,
  String? playerAvatarIcon,
  int? playerAvatarBgColor,
  bool arrived = false,
}) {

  return {
    'playerName': playerName.trim(),
    'playerLastName': (playerLastName ?? '').trim().isEmpty
        ? null
        : playerLastName!.trim(),
    'playerShortName': playerShortName.trim().isEmpty
        ? playerName.trim()
        : playerShortName.trim(),
    'playerUid': playerUid.trim().isEmpty ? null : playerUid.trim(),
    'playerPhotoUrl': (playerPhotoUrl ?? '').trim().isEmpty
        ? null
        : playerPhotoUrl!.trim(),
    'playerId': playerId.trim().isEmpty ? null : playerId.trim(),
    'playerAvatarType': (playerAvatarType ?? '').trim().isEmpty
        ? null
        : playerAvatarType!.trim(),
    'playerAvatarIcon': (playerAvatarIcon ?? '').trim().isEmpty
        ? null
        : playerAvatarIcon!.trim(),
    'playerAvatarBgColor': playerAvatarBgColor,
    'reservedForName': null,
    'reservedForShortName': null,
    'reservedForUid': null,
    'reservedForPlayerId': null,
    'reservedArrived': null,
    'arrived': arrived,
  };

}

Map<String, dynamic> buildReservedSeatMap({
  required String reservedForName,
  String? reservedForShortName,
  String? reservedForUid,
  String? reservedForPlayerId,
  bool reservedArrived = false,
}) {

  return {
    'playerName': null,
    'playerLastName': null,
    'playerShortName': null,
    'playerUid': null,
    'playerPhotoUrl': null,
    'playerId': null,
    'reservedForName': reservedForName.trim(),
    'reservedForShortName':
        (reservedForShortName ?? '').trim().isEmpty
            ? reservedForName.trim()
            : reservedForShortName!.trim(),
    'reservedForUid':
        (reservedForUid ?? '').trim().isEmpty ? null : reservedForUid!.trim(),
    'reservedForPlayerId':
        (reservedForPlayerId ?? '').trim().isEmpty
            ? null
            : reservedForPlayerId!.trim(),
    'reservedArrived': reservedArrived,
    'arrived': null,
  };

}

class TableData {
  String name;
  int playerSeatCount;
  List<SeatReservation> seats;
  DateTime? dateTime;
  String location;
  String stakes;
  List<Map<String, dynamic>> waitingList;
  String createdByUid;
  String createdByName;
  List<String> sharedHostUids;
  String? dealerName;

  TableData({
    required this.name,
    required this.playerSeatCount,
    required this.seats,
    this.dateTime,
    this.location = '',
    this.stakes = '',
    List<Map<String, dynamic>>? waitingList,
    required this.createdByUid,
    required this.createdByName,
    List<String>? sharedHostUids,
    this.dealerName,
  })  : waitingList = waitingList ?? [],
        sharedHostUids = sharedHostUids ?? [];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'playerSeatCount': playerSeatCount,
      'dateTime': dateTime?.toIso8601String(),
      'location': location,
      'stakes': stakes,
      'waitingList': waitingList,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'sharedHostUids': sharedHostUids,
      'dealerName': dealerName,
      'seats': seats.map((seat) => seat.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'version': 1,
    };
  }

  factory TableData.fromMap(Map<String, dynamic> map) {
    final rawSeats = List<dynamic>.from(map['seats'] ?? []);
  
    return TableData(
      name: map['name'] ?? '',
      playerSeatCount: map['playerSeatCount'] ?? 9,
      seats: rawSeats.map((seat) {
        if (seat is Map<String, dynamic>) {
          return SeatReservation.fromMap(seat);
        }
        if (seat is Map) {
          return SeatReservation.fromMap(Map<String, dynamic>.from(seat));
        }
        if (seat is String) {
          return SeatReservation(playerName: seat);
        }
        return SeatReservation();
      }).toList(),
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'])
          : null,
      location: map['location'] ?? '',
      stakes: map['stakes'] ?? '',
      waitingList: List<dynamic>.from(map['waitingList'] ?? [])
          .map((e) => normalizeWaitingEntry(e))
          .toList(),
      createdByUid: map['createdByUid'] ?? '',
      createdByName: map['createdByName'] ?? '',
      sharedHostUids: List<String>.from(map['sharedHostUids'] ?? []),
      dealerName: map['dealerName'],
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with AppVersionChecker {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  @override
  void initState() {
  
    super.initState();

    startVersionCheck();

  }

  Future<void> _loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
  
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter email and password');
      return;
    }
  
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
  
      final user = cred.user;
      if (user == null) {
        _showSnack('Login failed');
        return;
      }
  
      await ensureUserProfile(user);
  
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      if (data == null) {
        _showSnack('User profile not found');
        return;
      }

      final name =
          (data['displayName'] ?? user.displayName ?? 'User').toString();
      final roleText = (data['role'] ?? 'player').toString();
      final role = roleText == 'host' ? UserRole.host : UserRole.player;
  
      if (!mounted) return;
  
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TableListPage(
            session: UserSession(
              name: name,
              shortName: (data['shortName'] ?? name).toString(),
              role: role,
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Login failed');
    } on FirebaseException catch (e) {
      _showSnack(e.message ?? 'Firestore error');
    } catch (e) {
      _showSnack('Something went wrong');
    }
  }

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showSnack('Please enter your email first');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Password reset email sent. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to send reset email');
    } catch (e) {
      _showSnack('Failed to send reset email');
    }
  }

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _showGoogleLogin {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _signInWithApple() async {
    try {
      if (!await SignInWithApple.isAvailable()) {
        _showSnack('Apple Sign-In is not available on this device');
        return;
      }

      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final userCredential =
          await FirebaseAuth.instance.signInWithProvider(appleProvider);

      final user = userCredential.user;
      if (user == null) {
        _showSnack('Apple login failed: user is null');
        return;
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userDoc = await userRef.get();
      final data = userDoc.data();

      if (data == null) {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GoogleFirstSetupPage(user: user),
          ),
        );
        return;
      }

      await ensureUserProfile(user);

      final name =
          (data['displayName'] ?? user.displayName ?? user.email ?? 'User')
              .toString();

      final roleText = (data['role'] ?? 'player').toString();
      final role = roleText == 'host' ? UserRole.host : UserRole.player;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TableListPage(
            session: UserSession(
              name: name,
              shortName: (data['shortName'] ?? name).toString(),
              role: role,
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint('APPLE FIREBASE AUTH ERROR');
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrintStack(stackTrace: st);
      _showSnack('Apple login failed: ${e.code}');
    } catch (e, st) {
      debugPrint('APPLE LOGIN UNKNOWN ERROR: $e');
      debugPrintStack(stackTrace: st);
      _showSnack('Apple login failed: $e');
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      UserCredential userCredential;
  
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
  
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  
        if (googleUser == null) {
          _showSnack('Google sign-in cancelled');
          return;
        }
  
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
  
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
  
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }
  
      final user = userCredential.user;
      if (user == null) {
        _showSnack('Google login failed');
        return;
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userDoc = await userRef.get();
      final data = userDoc.data();
      
      // 第一次 Google 登入：先去設定名字與角色
      if (data == null) {
        if (!mounted) return;
      
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GoogleFirstSetupPage(user: user),
          ),
        );
        return;
      }

      await ensureUserProfile(user);

      final name =
          (data['displayName'] ?? user.displayName ?? user.email ?? 'User')
              .toString();
  
      final roleText = (data['role'] ?? 'player').toString();
      final role = roleText == 'host' ? UserRole.host : UserRole.player;
  
      if (!mounted) return;
  
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TableListPage(
            session: UserSession(
              name: name,
              shortName: (data['shortName'] ?? name).toString(),
              role: role,
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint('GOOGLE FIREBASE AUTH ERROR');
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrintStack(stackTrace: st);
      _showSnack('Google login failed: ${e.code}');
    } catch (e, st) {
      debugPrint('GOOGLE LOGIN UNKNOWN ERROR: $e');
      debugPrintStack(stackTrace: st);
      _showSnack('Google login failed: $e');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }



  @override
  void dispose() {
  
    stopVersionCheck();
  
    emailController.dispose();
  
    passwordController.dispose();
  
    super.dispose();
  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (hasNewVersion)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFE08A)),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'New version available. Tap Update.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7A5D00),
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: forceRefreshWebPage,
                                child: const Text('Update'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_isApplePlatform)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _signInWithApple,
                            icon: const Icon(Icons.apple),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Login with Apple',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (_isApplePlatform && _showGoogleLogin)
                        const SizedBox(height: 12),

                      if (_showGoogleLogin)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _signInWithGoogle,
                            icon: const Icon(Icons.login),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Login with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (_isApplePlatform || _showGoogleLogin)
                        const SizedBox(height: 20),

                      const Icon(Icons.sports_esports, size: 54),
                      const SizedBox(height: 14),
                      const Text(
                        'Poker Table Reservation',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loginWithEmail,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Login with Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Go to Register',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class GoogleFirstSetupPage extends StatefulWidget {
  final User user;

  const GoogleFirstSetupPage({
    super.key,
    required this.user,
  });

  @override
  State<GoogleFirstSetupPage> createState() => _GoogleFirstSetupPageState();
}

class _GoogleFirstSetupPageState extends State<GoogleFirstSetupPage> {
  late final TextEditingController displayNameController;
  final TextEditingController lastNameController = TextEditingController();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    final defaultName =
        (widget.user.displayName != null &&
                widget.user.displayName!.trim().isNotEmpty)
            ? widget.user.displayName!.trim()
            : (widget.user.email?.split('@').first ?? 'User');

    displayNameController = TextEditingController(text: defaultName);
  }

  Future<void> _saveProfile() async {
    final displayName = displayNameController.text.trim();
    final lastName = lastNameController.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter display name')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final shortName = await saveUserProfileData(
        user: widget.user,
        displayName: displayName,
        lastName: lastName,
        role: UserRole.player,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => TableListPage(
            session: UserSession(
              name: displayName,
              shortName: shortName,
              role: UserRole.player,
            ),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile')),
      );

      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    displayNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Set Up Account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.account_circle, size: 56),
                      const SizedBox(height: 14),
                      const Text(
                        'First Google Sign-In',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All new accounts start in Player mode. After payment, you can upgrade to Host.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: displayNameController,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'Enter your display name',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          hintText: 'Enter your last name',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isSaving ? null : _saveProfile,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              isSaving ? 'Saving...' : 'Continue',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  Future<void> _registerWithEmail() async {
    final displayName = displayNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (displayName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnack('Please fill in all required fields');
      return;
    }

    if (password != confirmPassword) {
      _showSnack('Passwords do not match');
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        _showSnack('Registration failed');
        return;
      }

      final shortName = await saveUserProfileData(
        user: user,
        displayName: displayName,
        lastName: lastName,
        role: UserRole.player,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => TableListPage(
            session: UserSession(
              name: displayName,
              shortName: shortName,
              role: UserRole.player,
            ),
          ),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Registration failed');
    } catch (e) {
      _showSnack('Registration failed');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    displayNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Register',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.person_add_alt_1, size: 54),
                      const SizedBox(height: 14),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your player account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: displayNameController,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'Enter your display name',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          hintText: 'Enter your last name (optional)',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Enter your password again',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _registerWithEmail,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TableListPage extends StatefulWidget {
  final UserSession session;

  const TableListPage({
    super.key,
    required this.session,
  });

  @override
  State<TableListPage> createState() => _TableListPageState();
}

class ProfileEditPage extends StatefulWidget {
  final UserSession session;

  const ProfileEditPage({
    super.key,
    required this.session,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = true;
  bool isSavingName = false;
  bool isSavingPassword = false;
  bool isUploadingAvatar = false;

  String? photoUrl;
  String avatarType = 'photo';
  String avatarIcon = 'person';
  int avatarBgColor = 0xFF2563EB;
  String email = '';
  String authProvider = 'password';
  String playerId = '';
  String roleText = 'player';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      String resolvedPhotoUrl = '';
      if (data?['photoUrl'] != null &&
          data!['photoUrl'].toString().trim().isNotEmpty) {
        resolvedPhotoUrl = data['photoUrl'].toString().trim();
      } else if ((user.photoURL ?? '').trim().isNotEmpty) {
        resolvedPhotoUrl = user.photoURL!.trim();
      }

      String resolvedPlayerId = (data?['playerId'] ?? '').toString().trim();
      if (resolvedPlayerId.isEmpty) {
        resolvedPlayerId = await generateUniquePlayerId();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'playerId': resolvedPlayerId,
        }, SetOptions(merge: true));
      }

      String resolvedLastName = (data?['lastName'] ?? '').toString();
      String resolvedDisplayName =
          (data?['displayName'] ?? user.displayName ?? '').toString();

      if (resolvedDisplayName.trim().isEmpty) {
        resolvedDisplayName = user.email?.split('@').first ?? 'User';
      }

      final shortName = buildShortName(resolvedDisplayName, resolvedLastName);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': resolvedDisplayName,
        'lastName': resolvedLastName,
        'shortName': shortName,
        'email': user.email,
      }, SetOptions(merge: true));

      final providerIds = user.providerData.map((e) => e.providerId).toList();
      final isGoogleUser = providerIds.contains('google.com');

      setState(() {
        email = user.email ?? '';
        displayNameController.text = resolvedDisplayName;
        lastNameController.text = resolvedLastName;
        playerId = resolvedPlayerId;
        roleText = (data?['role'] ?? 'player').toString();
        photoUrl = resolvedPhotoUrl.isEmpty ? null : resolvedPhotoUrl;
        avatarType = (data?['avatarType'] ?? 'photo').toString().trim().isEmpty
            ? 'photo'
            : (data?['avatarType'] ?? 'photo').toString().trim();
        avatarIcon = (data?['avatarIcon'] ?? 'person').toString().trim().isEmpty
            ? 'person'
            : (data?['avatarIcon'] ?? 'person').toString().trim();
        avatarBgColor = data?['avatarBgColor'] is int
            ? data!['avatarBgColor'] as int
            : 0xFF2563EB;
        authProvider = isGoogleUser ? 'google.com' : 'password';
        isLoading = false;
      });
    } catch (e) {
      final fallbackName =
          (user.displayName ?? user.email?.split('@').first ?? 'User');

      setState(() {
        email = user.email ?? '';
        displayNameController.text = fallbackName;
        lastNameController.text = '';
        photoUrl = user.photoURL;
        isLoading = false;
      });
      _showSnack('Failed to load profile');
    }
  }

  Future<void> _updateCurrentUserDoc({
    required User user,
    required String displayName,
    required String lastName,
    String? overridePhotoUrl,
    String? overrideAvatarType,
    String? overrideAvatarIcon,
    int? overrideAvatarBgColor,
  }) async {
    final cleanDisplayName = displayName.trim().isEmpty
        ? (user.displayName ?? user.email?.split('@').first ?? 'User')
        : displayName.trim();

    final cleanLastName = lastName.trim();

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final existingDoc = await userRef.get();
    final existingData = existingDoc.data() ?? {};

    String playerId = (existingData['playerId'] ?? '').toString().trim();
    if (playerId.isEmpty) {
      playerId = await generateUniquePlayerId();
    }

    await userRef.set(
      buildUserProfileMap(
        displayName: cleanDisplayName,
        lastName: cleanLastName,
        email: user.email ?? '',
        playerId: playerId,
        roleText: (existingData['role'] ?? 'player').toString(),
        photoUrl: overridePhotoUrl ?? photoUrl,
        avatarType: overrideAvatarType ?? avatarType,
        avatarIcon: overrideAvatarIcon ?? avatarIcon,
        avatarBgColor: overrideAvatarBgColor ?? avatarBgColor,
        grantedHostIds:
            List<dynamic>.from(existingData['grantedHostIds'] ?? <String>[]),
        blockedUids:
            List<dynamic>.from(existingData['blockedUids'] ?? <String>[]),
        isActive: existingData['isActive'] == false ? false : true,
        createdAt: existingData['createdAt'],
        includeCreatedAt: false,
      ),
      SetOptions(merge: true),
    );
  }

  Future<void> _syncMyAvatarToAllSeatedTables({
    required String uid,
    required String? photoUrl,
    required String avatarType,
    required String avatarIcon,
    required int avatarBgColor,
  }) async {
    final tablesSnap =
        await FirebaseFirestore.instance.collection('tables').get();

    final batch = FirebaseFirestore.instance.batch();
    int writeCount = 0;

    for (final doc in tablesSnap.docs) {
      final data = doc.data();
      final rawSeats = List<dynamic>.from(data['seats'] ?? []);

      bool changed = false;

      final updatedSeats = rawSeats.map((rawSeat) {
        Map<String, dynamic> seat;

        if (rawSeat is Map<String, dynamic>) {
          seat = Map<String, dynamic>.from(rawSeat);
        } else if (rawSeat is Map) {
          seat = Map<String, dynamic>.from(rawSeat);
        } else {
          return rawSeat;
        }

        final seatUid = (seat['playerUid'] ?? '').toString().trim();

        if (seatUid == uid) {
          seat['playerAvatarType'] = avatarType;
          seat['playerAvatarIcon'] = avatarIcon;
          seat['playerAvatarBgColor'] = avatarBgColor;
          seat['playerPhotoUrl'] =
              avatarType == 'virtual'
                  ? null
                  : ((photoUrl ?? '').trim().isEmpty ? null : photoUrl!.trim());
          changed = true;
        }

        return seat;
      }).toList();

      if (changed) {
        batch.update(doc.reference, {
          'seats': updatedSeats,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        writeCount++;
      }
    }

    if (writeCount > 0) {
      await batch.commit();
    }
  }

  Future<void> _saveAvatarSnapshot({
    required AvatarSnapshot avatar,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _updateCurrentUserDoc(
      user: user,
      displayName: displayNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      overridePhotoUrl: avatar.photoUrl,
      overrideAvatarType: avatar.avatarType,
      overrideAvatarIcon: avatar.avatarIcon,
      overrideAvatarBgColor: avatar.avatarBgColor,
    );

    await _syncMyAvatarToAllSeatedTables(
      uid: user.uid,
      photoUrl: avatar.photoUrl,
      avatarType: avatar.avatarType,
      avatarIcon: avatar.avatarIcon,
      avatarBgColor: avatar.avatarBgColor,
    );

    if (!mounted) return;

    setState(() {
      photoUrl = avatar.photoUrl;
      avatarType = avatar.avatarType;
      avatarIcon = avatar.avatarIcon;
      avatarBgColor = avatar.avatarBgColor;
    });
  }  

  Map<String, dynamic> _buildEmptySeatMap() {
    return {
      'playerName': null,
      'playerLastName': null,
      'playerShortName': null,
      'playerUid': null,
      'playerPhotoUrl': null,
      'playerId': null,
      'reservedForName': null,
      'reservedForShortName': null,
      'reservedForUid': null,
      'reservedForPlayerId': null,
      'reservedArrived': null,
      'arrived': null,
    };
  }

  Future<void> _saveBasicProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firstName = displayNameController.text.trim();
    final lastName = lastNameController.text.trim();

    if (firstName.isEmpty) {
      _showSnack('Display name cannot be empty');
      return;
    }

    setState(() {
      isSavingName = true;
    });

    try {
      final shortName = buildShortName(firstName, lastName);

      await user.updateDisplayName(firstName);
      await user.reload();

      await _updateCurrentUserDoc(
        user: user,
        displayName: firstName,
        lastName: lastName,
        overridePhotoUrl: photoUrl,
        overrideAvatarType: avatarType,
        overrideAvatarIcon: avatarIcon,
        overrideAvatarBgColor: avatarBgColor,
      );

      final tables = await FirebaseFirestore.instance.collection('tables').get();
      
      for (final doc in tables.docs) {
        final data = doc.data();
        final table = TableData.fromMap(data);
      
        bool changed = false;
      
        for (final seat in table.seats) {
          if ((seat.playerUid ?? '').trim() == user.uid) {
            seat.playerName = firstName;
            seat.playerLastName = lastName;
            seat.playerShortName = shortName;
            seat.playerPhotoUrl = photoUrl;
            changed = true;
          }
        }

        if (changed) {
          await doc.reference.update({
            'seats': table.seats.map((e) => e.toMap()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;

      _showSnack('Profile updated');

      if (mounted) {
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to update profile');
    } catch (e) {
      _showSnack('Failed to update profile');
    }

    if (mounted) {
      setState(() {
        isSavingName = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (authProvider == 'google.com') {
      _showSnack('Google login account cannot change password here');
      return;
    }

    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnack('Please fill in both password fields');
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnack('Passwords do not match');
      return;
    }

    if (newPassword.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }

    setState(() {
      isSavingPassword = true;
    });

    try {
      await user.updatePassword(newPassword);
      newPasswordController.clear();
      confirmPasswordController.clear();
      _showSnack('Password updated');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack('Please logout and login again first, then change password');
      } else {
        _showSnack(e.message ?? 'Failed to update password');
      }
    } catch (e) {
      _showSnack('Failed to update password');
    }

    if (mounted) {
      setState(() {
        isSavingPassword = false;
      });
    }
  }

  Future<void> _uploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isUploadingAvatar = true;
    });

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (file == null) {
        setState(() {
          isUploadingAvatar = false;
        });
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';

      String ext = 'jpg';
      if (mimeType.contains('png')) {
        ext = 'png';
      } else if (mimeType.contains('webp')) {
        ext = 'webp';
      } else if (mimeType.contains('gif')) {
        ext = 'gif';
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(user.uid)
          .child('avatar.$ext');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );

      final downloadUrl = await ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);

      final avatar = AvatarSnapshot(
        avatarType: 'photo',
        avatarIcon: avatarIcon,
        avatarBgColor: avatarBgColor,
        photoUrl: downloadUrl,
      );

      await _saveAvatarSnapshot(
        avatar: avatar,
      );

      await user.reload();

      if (!mounted) return;

      setState(() {
        isUploadingAvatar = false;
      });

      _showSnack('Avatar updated');
    } catch (e) {
      setState(() {
        isUploadingAvatar = false;
      });

      _showSnack('Failed to upload avatar');
    }
  }

  Future<void> _removeAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.updatePhotoURL(null);

      final avatar = AvatarSnapshot(
        avatarType: 'virtual',
        avatarIcon: avatarIcon,
        avatarBgColor: avatarBgColor,
        photoUrl: null,
      );

      await _saveAvatarSnapshot(
        avatar: avatar,
      );

      _showSnack('Avatar removed');
    } catch (e) {
      _showSnack('Failed to remove avatar');
    }
  }

  Future<void> _pickVirtualAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String tempIcon = avatarIcon;
    int tempColor = avatarBgColor;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Choose Virtual Avatar'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildAppAvatar(
                      radius: 36,
                      avatar: AvatarSnapshot(
                        avatarType: 'virtual',
                        avatarIcon: tempIcon,
                        avatarBgColor: tempColor,
                        photoUrl: null,
                      ),
                      displayName: displayNameController.text.trim(),
                      iconSize: 34,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kVirtualAvatarIcons.map((iconKey) {
                        final isSelected = tempIcon == iconKey;
                        return ChoiceChip(
                          label: Icon(
                            virtualAvatarIconData(iconKey),
                            size: 18,
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setLocalState(() {
                              tempIcon = iconKey;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kVirtualAvatarColors.map((colorValue) {
                        final isSelected = tempColor == colorValue;
                        return GestureDetector(
                          onTap: () {
                            setLocalState(() {
                              tempColor = colorValue;
                            });
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'avatarIcon': tempIcon,
                      'avatarBgColor': tempColor,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final nextAvatarIcon = result['avatarIcon'].toString();
      final nextAvatarBgColor = result['avatarBgColor'] as int;

      await _updateCurrentUserDoc(
        user: user,
        displayName: displayNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        overridePhotoUrl: null,
        overrideAvatarType: 'virtual',
        overrideAvatarIcon: nextAvatarIcon,
        overrideAvatarBgColor: nextAvatarBgColor,
      );

      await _syncMyAvatarToAllSeatedTables(
        uid: user.uid,
        photoUrl: null,
        avatarType: 'virtual',
        avatarIcon: nextAvatarIcon,
        avatarBgColor: nextAvatarBgColor,
      );

      if (!mounted) return;

      setState(() {
        avatarType = 'virtual';
        avatarIcon = (result['avatarIcon'] ?? 'person').toString();
        avatarBgColor = result['avatarBgColor'] is int
            ? result['avatarBgColor'] as int
            : 0xFF2563EB;
      });

      _showSnack('Virtual avatar updated');
    } catch (e) {
      _showSnack('Failed to update virtual avatar');
    }
  }

  Future<void> _deactivateMyAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
  
    try {
      final uid = user.uid;
  
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
  
      final tables = await FirebaseFirestore.instance.collection('tables').get();
  
      for (final doc in tables.docs) {
        final data = doc.data();
  
        final rawSeatsDynamic = List<dynamic>.from(data['seats'] ?? []);
        final List<Map<String, dynamic>> newSeats = [];
        bool changed = false;
  
        for (final raw in rawSeatsDynamic) {
          if (raw is Map) {
            final seat = Map<String, dynamic>.from(raw);
  
            if ((seat['playerUid'] ?? '').toString() == uid) {
              newSeats.add(_buildEmptySeatMap());
              changed = true;
            } else {
              newSeats.add(seat);
            }

          } else if (raw is String) {
            newSeats.add({
              'playerName': raw,
              'playerLastName': null,
              'playerShortName': raw,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            });
          } else {
            newSeats.add({
              'playerName': null,
              'playerLastName': null,
              'playerShortName': null,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            });
          }
        }
  
        if (changed) {
          await doc.reference.update({
            'seats': newSeats,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
  
      await user.delete();
  
      if (!mounted) return;
  
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack('Please logout and login again before deleting your account');
      } else {
        _showSnack(e.message ?? 'Failed to delete account');
      }
    } catch (e) {
      _showSnack('Failed to delete account');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    displayNameController.dispose();
    lastNameController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  buildAppAvatar(
                                    radius: 48,
                                    avatar: AvatarSnapshot(
                                      avatarType: avatarType,
                                      avatarIcon: avatarIcon,
                                      avatarBgColor: avatarBgColor,
                                      photoUrl: photoUrl,
                                    ),
                                    displayName: displayNameController.text.trim(),
                                    iconSize: 42,
                                    textSize: 28,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: isUploadingAvatar
                                            ? null
                                            : _uploadAvatar,
                                        icon: const Icon(Icons.photo_camera),
                                        label: Text(
                                          isUploadingAvatar
                                              ? 'Uploading...'
                                              : 'Upload Avatar',
                                        ),
                                      ),

                                      OutlinedButton.icon(
                                        onPressed: _pickVirtualAvatar,
                                        icon: const Icon(Icons.auto_awesome),
                                        label: const Text('Virtual Avatar'),
                                      ),

                                      if (photoUrl != null &&
                                          photoUrl!.trim().isNotEmpty)
                                        OutlinedButton.icon(
                                          onPressed: _removeAvatar,
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Remove Avatar'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6F8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Player ID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SelectableText(
                                          playerId.isEmpty ? '-' : playerId,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'This ID is unique and cannot be changed.',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Basic Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: displayNameController,
                              decoration: InputDecoration(
                                labelText: 'Display Name',
                                hintText: 'Enter your display name',
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: lastNameController,
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                hintText: 'Enter your last name',
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    isSavingName ? null : _saveBasicProfile,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    isSavingName
                                        ? 'Saving...'
                                        : 'Save Profile',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (authProvider == 'google.com')
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFFE082),
                                  ),
                                ),
                                child: const Text(
                                  'This account uses Google login, so password cannot be changed here.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else ...[
                              TextField(
                                controller: newPasswordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password',
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: isSavingPassword
                                      ? null
                                      : _changePassword,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                    child: Text(
                                      isSavingPassword
                                          ? 'Saving...'
                                          : 'Change Password',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                'Danger Zone',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Account'),
                                      content: const Text(
                                        'This will deactivate your account and remove your occupied seats. This cannot be undone.\n\nDo you want to continue?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                              
                                  if (confirmed == true) {
                                    await _deactivateMyAccount();
                                  }
                                },
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Delete My Account'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}


class _TableListPageState extends State<TableListPage> with AppVersionChecker {
  bool _canManageTable(TableData table) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final currentName = widget.session.name.trim();

    return isSuperAdmin ||
        table.createdByUid == currentUid ||
        (table.createdByUid.trim().isEmpty &&
            table.createdByName.trim() == currentName);
  }

  @override
  void initState() {
    super.initState();
    startVersionCheck();
    _listenToCurrentUserAccess();
  }

  void _listenToCurrentUserAccess() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    _userDocSub?.cancel();

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .snapshots()
        .listen((doc) async {
      final data = doc.data() ?? {};
      final status = resolveHostSubscriptionStatusFromUserData(data);

      if (status.shouldDowngradeToPlayer) {
        await doc.reference.set({
          'role': 'player',
          'hostDowngradedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        setState(() {
          _hostSubscriptionStatus = const HostSubscriptionStatus.player();
        });
        return;
      }

      if (!mounted) return;

      final statsStatus = resolveStatsSubscriptionStatusFromUserData(data);

      setState(() {
        _hostSubscriptionStatus = status;
        _statsSubscriptionStatus = statsStatus;
      });
    });
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    stopVersionCheck();
    super.dispose();
  }

  String _formatHostExpiry(DateTime? value) {
    if (value == null) return '';
    return '${value.year}/${value.month}/${value.day} ${value.hour}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _buildHostPaymentBannerText() {
    final expiresAt = _hostSubscriptionStatus.expiresAt;
    final graceEndsAt = _hostSubscriptionStatus.graceEndsAt;

    if (_hostSubscriptionStatus.isPaidActive && expiresAt != null) {
      final remainingDays =
          math.max(0, (expiresAt.difference(DateTime.now()).inHours / 24).ceil());

      return 'Your Host plan expires in $remainingDays day(s). Please update payment before ${_formatHostExpiry(expiresAt)}.';
    }

    if (_hostSubscriptionStatus.isGracePeriod && graceEndsAt != null) {
      final remainingDays =
          math.max(0, (graceEndsAt.difference(DateTime.now()).inHours / 24).ceil());

      return 'Your Host plan has expired. Update payment to create new tables. If unpaid for $remainingDays more day(s), your account will return to Player mode.';
    }

    return 'Please update your Host payment.';
  }

  Future<void> _activateHostPlanForCurrentUser({
    int durationDays = 30,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    await activateHostSubscriptionForUserUid(
      uid,
      durationDays: durationDays,
    );

    if (!mounted) return;
    _showSnack('Host payment updated successfully');
  }

  Future<void> _showUpdatePaymentDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Payment'),
          content: Text(
            _hostSubscriptionStatus.isGracePeriod
                ? 'Your Host plan has expired. You can still edit your existing tables, but you cannot create a new table until payment is updated.'
                : 'Your Host plan is close to expiring. Please update payment now so Table creation will not be interrupted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _startStripeCheckout();
              },
              child: const Text('Update Payment'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAddTablePressed() async {
    if (!isHost) return;

    if (!canCreateTables) {
      await _startStripeCheckout();
      return;
    }

    await _addTable();
  }

  Future<void> _editTable(String tableId, TableData table) async {
    if (!isHost) return;
  
    if (!_canManageTable(table)) {
      _showSnack('You can only edit tables you created');
      return;
    }
  
    final tableNameController = TextEditingController(text: table.name);
    final locationController = TextEditingController(text: table.location);
    final stakesController = TextEditingController(text: table.stakes);

    int selectedSeatCount = table.playerSeatCount;
    DateTime selectedDateTime = table.dateTime ?? DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Table'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tableNameController,
                      decoration: const InputDecoration(
                        labelText: 'Table Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stakesController,
                      decoration: const InputDecoration(
                        labelText: 'Stakes',
                        hintText: 'ex: 1/3 NLH',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedSeatCount,
                      decoration: const InputDecoration(
                        labelText: 'Player Seats',
                      ),
                      items: const [
                        DropdownMenuItem(value: 9, child: Text('9 Players')),
                        DropdownMenuItem(value: 10, child: Text('10 Players')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedSeatCount = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date & Time'),
                      subtitle: Text(
                        '${selectedDateTime.year}/${selectedDateTime.month}/${selectedDateTime.day} '
                        '${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );

                        if (!context.mounted) return;
                        if (pickedDate == null) return;

                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );

                        if (!context.mounted) return;
                        if (pickedTime == null) return;

                        setDialogState(() {
                          selectedDateTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    
    try {
      final tableRef = tablesRef.doc(tableId);
    
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(tableRef);
        final data = snap.data();
    
        if (data == null) {
          throw Exception('Table not found');
        }
    
        final rawSeats = List<dynamic>.from(data['seats'] ?? []);
    
        final seatList = rawSeats.map((seat) {
          if (seat is Map<String, dynamic>) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is Map) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is String) {
            return <String, dynamic>{
              'playerName': seat,
              'playerLastName': null,
              'playerShortName': seat,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            };
          }
          return <String, dynamic>{
            'playerName': null,
            'playerLastName': null,
            'playerShortName': null,
            'playerUid': null,
            'playerPhotoUrl': null,
            'playerId': null,
          };
        }).toList();
    
        bool isSeatEmpty(Map<String, dynamic> seat) {
          final playerName = (seat['playerName'] ?? '').toString().trim();
          final playerUid = (seat['playerUid'] ?? '').toString().trim();
          final playerId = (seat['playerId'] ?? '').toString().trim();
    
          return playerName.isEmpty && playerUid.isEmpty && playerId.isEmpty;
        }
    
        if (selectedSeatCount > seatList.length) {
          while (seatList.length < selectedSeatCount) {
            seatList.add({
              'playerName': null,
              'playerLastName': null,
              'playerShortName': null,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            });
          }
        } else if (selectedSeatCount < seatList.length) {
          while (seatList.length > selectedSeatCount) {
            int removeIndex = -1;
    
            for (int i = seatList.length - 1; i >= 0; i--) {
              final seat = Map<String, dynamic>.from(seatList[i]);
              if (isSeatEmpty(seat)) {
                removeIndex = i;
                break;
              }
            }
    
            if (removeIndex == -1) {
              throw Exception(
                'Cannot reduce seat count because there are no empty seats to remove',
              );
            }
    
            seatList.removeAt(removeIndex);
          }
        }
    
        tx.update(tableRef, {
          'name': tableNameController.text.trim(),
          'location': locationController.text.trim(),
          'stakes': stakesController.text.trim(),
          'dateTime': selectedDateTime.toIso8601String(),
          'playerSeatCount': selectedSeatCount,
          'seats': seatList,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    
      _showSnack('Table updated');
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  
  HostSubscriptionStatus _hostSubscriptionStatus =
      const HostSubscriptionStatus.player();
  
  StatsSubscriptionStatus _statsSubscriptionStatus =
      const StatsSubscriptionStatus.unpaid();
  
  bool get isHost {
    return _hostSubscriptionStatus.isHostRole;
  }

  bool get canCreateTables {
    if (!isHost) return false;

    if (_hostSubscriptionStatus.expiresAt == null) {
      return true;
    }

    return _hostSubscriptionStatus.canCreateTable;
  }

  bool get showHostPaymentBanner => _hostSubscriptionStatus.showRenewBanner;

  bool get hasStatsAccess => _statsSubscriptionStatus.isPaidActive;
  
  String get statsPlanText {
    final expiresAt = _statsSubscriptionStatus.expiresAt;
  
    if (expiresAt == null) {
      return 'Unpaid';
    }

    return 'Active until ${expiresAt.year}/${expiresAt.month}/${expiresAt.day}';
  }

  bool get isSuperAdmin =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ==
      superAdminEmail.toLowerCase();

  final tablesRef = FirebaseFirestore.instance.collection('tables');

  UserSession get effectiveSession => UserSession(
        name: widget.session.name,
        shortName: widget.session.shortName,
        role: isHost ? UserRole.host : UserRole.player,
      );

  Widget _buildTablesSection() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';

    if (currentUid.isEmpty) {
      return const Center(child: Text('Please login again'));
    }

    if (isSuperAdmin) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tablesRef
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load tables'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final table = TableData.fromMap(doc.data());

              return _buildTableCard(
                context: context,
                tableId: doc.id,
                table: table,
                index: index,
              );
            },
          );
        },
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError) {
          return const Center(child: Text('Failed to load access'));
        }

        final userData = userSnapshot.data?.data() ?? {};
        final grantedHostIds =
            List<String>.from(userData['grantedHostIds'] ?? []);

        if (isHost) {
          final createdByMeStream = tablesRef
              .where('createdByUid', isEqualTo: currentUid)
              .snapshots();

          Stream<QuerySnapshot<Map<String, dynamic>>>? grantedTablesStream;

          if (grantedHostIds.isNotEmpty) {
            grantedTablesStream = tablesRef
                .where('createdByUid', whereIn: grantedHostIds.take(10).toList())
                .snapshots();
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: createdByMeStream,
            builder: (context, mySnapshot) {
              if (mySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (mySnapshot.hasError) {
                return const Center(child: Text('Failed to load your tables'));
              }

              if (grantedTablesStream == null) {
                final docs = mySnapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final table = TableData.fromMap(doc.data());

                    return _buildTableCard(
                      context: context,
                      tableId: doc.id,
                      table: table,
                      index: index,
                    );
                  },
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: grantedTablesStream,
                builder: (context, grantedSnapshot) {
                  if (grantedSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (grantedSnapshot.hasError) {
                    return const Center(child: Text('Failed to load granted tables'));
                  }

                  final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

                  for (final doc in mySnapshot.data?.docs ?? []) {
                    merged[doc.id] = doc;
                  }

                  for (final doc in grantedSnapshot.data?.docs ?? []) {
                    merged[doc.id] = doc;
                  }

                  final docs = merged.values.toList()
                    ..sort((a, b) {
                      final aCreated = a.data()['createdAt'];
                      final bCreated = b.data()['createdAt'];

                      if (aCreated is Timestamp && bCreated is Timestamp) {
                        return aCreated.compareTo(bCreated);
                      }

                      return 0;
                    });

                  if (docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final table = TableData.fromMap(doc.data());

                      return _buildTableCard(
                        context: context,
                        tableId: doc.id,
                        table: table,
                        index: index,
                      );
                    },
                  );
                },
              );
            },
          );
        }

        if (grantedHostIds.isEmpty) {
          return _buildEmptyState();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tablesRef
              .where('createdByUid', whereIn: grantedHostIds.take(10).toList())
              .snapshots(),
          builder: (context, tableSnapshot) {
            if (tableSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (tableSnapshot.hasError) {
              return Center(
                child: Text('Failed to load tables: ${tableSnapshot.error}'),
              );
            }

            final docs = tableSnapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final table = TableData.fromMap(doc.data());

                return _buildTableCard(
                  context: context,
                  tableId: doc.id,
                  table: table,
                  index: index,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showGrantPlayerAccessDialog() async {
    if (!isHost) return;
  
    final controller = TextEditingController();
  
    final playerId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Player by ID'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[A-Za-z0-9]'),
            ),
            LengthLimitingTextInputFormatter(8),
            UpperCaseTextFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: 'Player ID',
            hintText: 'Enter 8-character Player ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim().toUpperCase()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (playerId == null || playerId.isEmpty) return;
  
    await _grantPlayerAccessByPlayerId(playerId);
  }
  
  Future<void> _grantPlayerAccessByPlayerId(String playerId) async {
    final hostUser = FirebaseAuth.instance.currentUser;
    if (hostUser == null) return;

    final cleanPlayerId = playerId.trim().toUpperCase();

    if (cleanPlayerId.isEmpty) {
      _showSnack('Please enter Player ID');
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore.instance
          .collection('users')
          .where('playerId', isEqualTo: cleanPlayerId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await FirebaseFirestore.instance
            .collection('users')
            .where('playerIdLower', isEqualTo: cleanPlayerId.toLowerCase())
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        _showSnack('Player ID not found');
        return;
      }

      final playerDoc = query.docs.first;
      final playerData = playerDoc.data();

      if (playerDoc.id == hostUser.uid) {
        _showSnack('You cannot add yourself');
        return;
      }

      final grantedHostIds =
          List<String>.from(playerData['grantedHostIds'] ?? []);

      if (grantedHostIds.contains(hostUser.uid)) {
        _showSnack('This player is already added');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(playerDoc.id)
          .update({
        'grantedHostIds': FieldValue.arrayUnion([hostUser.uid]),
        'playerIdLower': (playerData['playerId'] ?? cleanPlayerId)
            .toString()
            .trim()
            .toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final addedName =
          (playerData['shortName'] ?? playerData['displayName'] ?? 'Player')
              .toString()
              .trim();

      _showSnack('$addedName added successfully');
    } on FirebaseException catch (e) {
      _showSnack(e.message ?? 'Failed to add player');
    } catch (e) {
      _showSnack('Failed to add player: $e');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _addTable() async {
    if (!canCreateTables) return;
  
    final result = await _showCreateTableDialog();
    if (result == null) return;
  
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentName = widget.session.name.trim();
  
    final tableData = result.toMap();
  
    tableData['createdByUid'] = currentUid;
    tableData['createdByName'] = currentName;
  
    await tablesRef.add(tableData);
  }

  Future<void> _shareTableWithHostByPlayerId({
    required String tableId,
    required String hostPlayerId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final cleanHostPlayerId = hostPlayerId.trim().toUpperCase();

    if (cleanHostPlayerId.isEmpty) {
      _showSnack('Please enter Host ID');
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('playerId', isEqualTo: cleanHostPlayerId)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        query = await FirebaseFirestore.instance
            .collection('users')
            .where(
              'playerIdLower',
              isEqualTo: cleanHostPlayerId.toLowerCase(),
            )
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        _showSnack('Host ID not found');
        return;
      }

      final targetDoc = query.docs.first;
      final targetData = targetDoc.data();

      if (targetDoc.id == currentUser.uid) {
        _showSnack('You cannot share with yourself');
        return;
      }

      final targetRole = (targetData['role'] ?? 'player').toString().trim();
      if (targetRole != 'host') {
        _showSnack('This ID does not belong to a host');
        return;
      }

      final tableRef = tablesRef.doc(tableId);
      final tableSnap = await tableRef.get();
      final tableData = tableSnap.data();

      if (tableData == null) {
        _showSnack('Table not found');
        return;
      }

      final table = TableData.fromMap(tableData);

      if (!_canManageTable(table)) {
        _showSnack('You can only share tables you created');
        return;
      }

      final sharedHostUids =
          List<String>.from(tableData['sharedHostUids'] ?? []);

      if (sharedHostUids.contains(targetDoc.id)) {
        _showSnack('This host already has access');
        return;
      }

      await tableRef.update({
        'sharedHostUids': FieldValue.arrayUnion([targetDoc.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final addedName =
          (targetData['shortName'] ?? targetData['displayName'] ?? 'Host')
              .toString()
              .trim();

      _showSnack('$addedName can now see this table');
    } on FirebaseException catch (e) {
      _showSnack(e.message ?? 'Failed to share table');
    } catch (e) {
      _showSnack('Failed to share table: $e');
    }
  }

  Future<void> _deleteTable(String tableId, TableData table) async {
    if (!isHost) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final currentName = widget.session.name.trim();
    
    final canManageThisTable =
        isSuperAdmin ||
        table.createdByUid == currentUid ||
        (table.createdByUid.trim().isEmpty &&
            table.createdByName.trim() == currentName);

    if (!canManageThisTable) {
      _showSnack('You can only delete tables you created');
      return;
    }

    await tablesRef.doc(tableId).delete();
  }

  void _openTable(String tableId, TableData table) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TableDetailPage(
          session: effectiveSession,
          table: table,
          tableId: tableId,
        ),
      ),
    );
  }

  Future<TableData?> _showCreateTableDialog() async {
    final tableNameController = TextEditingController(text: 'New Table');
    final locationController = TextEditingController();
    final stakesController = TextEditingController(text: '1/3 NLH');

    int selectedSeatCount = 9;
    DateTime selectedDateTime = DateTime.now();

    return showDialog<TableData>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Table'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tableNameController,
                      decoration: const InputDecoration(
                        labelText: 'Table Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stakesController,
                      decoration: const InputDecoration(
                        labelText: 'Stakes',
                        hintText: 'ex: 1/3 NLH',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedSeatCount,
                      decoration: const InputDecoration(
                        labelText: 'Player Seats',
                      ),
                      items: const [
                        DropdownMenuItem(value: 9, child: Text('9 Players')),
                        DropdownMenuItem(value: 10, child: Text('10 Players')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedSeatCount = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date & Time'),
                      subtitle: Text(
                        '${selectedDateTime.year}/${selectedDateTime.month}/${selectedDateTime.day} '
                        '${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );

                        if (!context.mounted) return;
                        if (pickedDate == null) return;

                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );

                        if (!context.mounted) return;
                        if (pickedTime == null) return;

                        setDialogState(() {
                          selectedDateTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final tableName = tableNameController.text.trim();
                    if (tableName.isEmpty) return;
                    Navigator.pop(
                      context,
                      TableData(
                        name: tableName,
                        playerSeatCount: selectedSeatCount,
                        seats: List.generate(
                          selectedSeatCount,
                          (_) => SeatReservation(),
                        ),
                        dateTime: selectedDateTime,
                        location: locationController.text.trim(),
                        stakes: stakesController.text.trim(),
                        createdByUid: FirebaseAuth.instance.currentUser!.uid,
                        createdByName: widget.session.name,
                        dealerName: null,
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _openStripeCheckoutFromFunction(String functionUrl) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnack('Please login again');
      return;
    }

    try {
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showSnack('Failed to create checkout: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final checkoutUrl = (data['url'] ?? '').toString();

      if (checkoutUrl.isEmpty) {
        _showSnack('Checkout URL is empty');
        return;
      }

      final ok = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        _showSnack('Cannot open payment page');
      }
    } catch (e) {
      print('openStripeCheckoutFromFunction error: $e');
      _showSnack('Failed to open payment page: $e');
    }
  }

  static const String _createHostCheckoutUrl =
      'https://us-central1-poker-scheduler-fd8c7.cloudfunctions.net/createHostCheckoutSession';

  static const String _createStatsCheckoutUrl =
      'https://us-central1-poker-scheduler-fd8c7.cloudfunctions.net/createStatsCheckoutSession';

  Future<void> _startStripeCheckout() async {
    if (isAppleIapPlatform) {
      try {
        await AppleIapService.buy(
          productId: kAppleHostProProductId,
          type: ApplePurchaseType.host,
        );

        _showSnack('Host Pro activated');

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }

      return;
    }

    await _openStripeCheckoutFromFunction(kCreateHostCheckoutUrl);
  }

  Future<void> _startStatsCheckout() async {
    if (isAppleIapPlatform) {
      try {
        await AppleIapService.buy(
          productId: kAppleStatsProProductId,
          type: ApplePurchaseType.stats,
        );

        _showSnack('Stats Pro activated');

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }

      return;
    }

    await _openStripeCheckoutFromFunction(kCreateStatsCheckoutUrl);
  }

  Future<void> _openCashStatsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CashGameStatsPage(
          session: effectiveSession,
          hasPaidAccess: hasStatsAccess,
          paymentUrl: kCreateStatsCheckoutUrl,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openFriendsHub() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsHubPage(
          session: widget.session,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildTopBanner() {
    final isHostView = isHost;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHostView
              ? const [Color(0xFF163D2E), Color(0xFF245B45)]
              : const [Color(0xFF1E3A5F), Color(0xFF2C5E92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHostView ? 'Host Dashboard' : 'Player Lobby',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHostView
                ? 'Create tables, manage reservations, and control table details.'
                : 'Browse tables, join a seat, and track available games.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenu() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 50),
        onSelected: (value) async {
          if (value == 'edit_profile') {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileEditPage(
                  session: widget.session,
                ),
              ),
            );
          
            if (mounted) {
              setState(() {});
            }
          } else if (value == 'grant_player_access') {
            await _showGrantPlayerAccessDialog();
          } else if (value == 'logout') {
            _logout();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'user',
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.shortName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'edit_profile',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit Profile'),
              ],
            ),
          ),

          if (isHost)
            const PopupMenuItem<String>(
              value: 'grant_player_access',
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Add Player by ID'),
                ],
              ),
            ),
          const PopupMenuItem<String>(
            value: 'logout',   
            child: Row(
              children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text('Logout'),
              ],
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            final user = FirebaseAuth.instance.currentUser;
            final displayName = widget.session.shortName;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() ?? {};
                      return buildAppAvatar(
                        radius: 16,
                        avatar: resolveAvatarSnapshotFromMap({
                          'photoUrl': (data['photoUrl'] ?? user?.photoURL)?.toString(),
                          'avatarType': data['avatarType'],
                          'avatarIcon': data['avatarIcon'],
                          'avatarBgColor': data['avatarBgColor'],
                        }),
                        displayName: displayName,
                        iconSize: 16,
                        textSize: 12,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha:0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateText(DateTime? dateTime) {
    if (dateTime == null) return 'No time';
    return '${dateTime.month}/${dateTime.day} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTableCard({
    required BuildContext context,
    required String tableId,
    required TableData table,
    required int index,
  }) {
    final bool isMyTable = _canManageTable(table);
  
    final takenCount = table.seats.where((seat) => !seat.isOpen).length;
    final openCount = table.playerSeatCount - takenCount;
  
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openTable(tableId, table),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9F7BE), Color(0xFFB7EB8F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF245B45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            table.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatChip(
                                icon: Icons.schedule,
                                label: _formatDateText(table.dateTime),
                                color: Colors.blue,
                              ),
                              if (table.stakes.isNotEmpty)
                                _buildStatChip(
                                  icon: Icons.casino,
                                  label: table.stakes,
                                  color: Colors.orange,
                                ),
                              _buildStatChip(
                                icon: Icons.event_seat,
                                label: '${table.playerSeatCount} seats',
                                color: Colors.black87,
                              ),
                              _buildStatChip(
                                icon: Icons.check_circle,
                                label: 'Open $openCount',
                                color: Colors.green,
                              ),
                              _buildStatChip(
                                icon: Icons.person_remove_alt_1,
                                label: 'Taken $takenCount',
                                color: Colors.red,
                              ),
                              if (table.location.isNotEmpty)
                                _buildStatChip(
                                  icon: Icons.location_on,
                                  label: table.location,
                                  color: Colors.purple,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            table.dealerName?.trim().isNotEmpty == true
                                ? 'Dealer: ${table.dealerName}'
                                : 'Dealer: Not set',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            isHost
                ? Builder(
                    builder: (menuContext) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final overlay =
                                Overlay.of(menuContext).context.findRenderObject() as RenderBox;
                            final button =
                                menuContext.findRenderObject() as RenderBox;
            
                            final position = RelativeRect.fromRect(
                              Rect.fromPoints(
                                button.localToGlobal(Offset.zero, ancestor: overlay),
                                button.localToGlobal(
                                  button.size.bottomRight(Offset.zero),
                                  ancestor: overlay,
                                ),
                              ),
                              Offset.zero & overlay.size,
                            );
            
                            final value = await showMenu<String>(
                              context: menuContext,
                              position: position,
                              items: [
                                const PopupMenuItem<String>(
                                  value: 'open',
                                  child: Text('Open Table'),
                                ),
                                if (isMyTable || isSuperAdmin)
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit Table'),
                                  ),
                                if (isMyTable || isSuperAdmin)
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Delete Table'),
                                  ),
                              ],
                            );
            
                            if (value == 'open') {
                              _openTable(tableId, table);
                            } else if (value == 'edit') {
                              _editTable(tableId, table);
                            } else if (value == 'delete') {
                              _deleteTable(tableId, table);
                            }
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.more_vert, size: 24),
                          ),
                        ),
                      );
                    },
                  )
                : const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(Icons.chevron_right),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.table_restaurant,
              size: 72,
              color: Colors.black38,
            ),
            const SizedBox(height: 14),
            const Text(
              'No tables yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              isHost
                  ? (canCreateTables
                      ? 'Tap the Add Table button to create your first poker table.'
                      : 'Update payment to create a new table. You can still open and edit your existing tables.')
                  : 'No tables are available right now.',
            
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

  @override
  Widget build(BuildContext context) {
    final roleText = isHost ? 'Host' : 'Player';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Table List ($roleText)',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Cash Game Stats',
            onPressed: _openCashStatsPage,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bar_chart_rounded),
                if (!hasStatsAccess)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FriendsNotificationButton(
            onTap: _openFriendsHub,
          ),
          _buildProfileMenu(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isHost ? _handleAddTablePressed : _startStripeCheckout,
        backgroundColor: isHost
            ? const Color(0xFFB9F0A9)
            : const Color(0xFFDBEAFE),
        foregroundColor: isHost
            ? const Color(0xFF163D2E)
            : const Color(0xFF1D4ED8),
        icon: Icon(isHost ? Icons.add : Icons.workspace_premium),
        label: Text(
          isHost ? 'Add Table' : 'Upgrade to Host',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (hasNewVersion)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'New version available. Tap Update.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A5D00),
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: forceRefreshWebPage,
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),

            if (showHostPaymentBanner)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _buildHostPaymentBannerText(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A5D00),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _startStripeCheckout,
                      child: const Text('Update Payment'),
                    ),
                  ],
                ),
              ),
              
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildTopBanner(),
            ),
            Expanded(
              child: _buildTablesSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendsNotificationButton extends StatelessWidget {
  final VoidCallback onTap;

  const FriendsNotificationButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty) {
      return IconButton(
        onPressed: onTap,
        tooltip: 'Friends & Chat',
        icon: const Icon(Icons.people_alt_outlined),
      );
    }

    final incomingRequestsStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final directChatsStream = FirebaseFirestore.instance
        .collection('direct_chats')
        .where('memberUids', arrayContains: currentUid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: incomingRequestsStream,
      builder: (context, requestSnapshot) {
        final requestCount = requestSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: directChatsStream,
          builder: (context, chatSnapshot) {
            return FutureBuilder<List<String>>(
              future: loadBlockedChatIdsForCurrentUser(currentUid),
              builder: (context, blockedSnapshot) {
                final blockedChatIds = blockedSnapshot.data ?? [];
                int unreadMessageCount = 0;

                for (final doc
                    in chatSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                  if (blockedChatIds.contains(doc.id)) {
                    continue;
                  }

                  final data = doc.data();
                  final unreadCounts =
                      Map<String, dynamic>.from(data['unreadCounts'] ?? {});
                  final rawCount = unreadCounts[currentUid] ?? 0;

                  if (rawCount is int) {
                    unreadMessageCount += rawCount;
                  } else {
                    unreadMessageCount += int.tryParse(rawCount.toString()) ?? 0;
                  }
                }

                final totalBadgeCount = requestCount + unreadMessageCount;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: onTap,
                      tooltip: 'Friends & Chat',
                      icon: const Icon(Icons.people_alt_outlined),
                    ),
                    if (totalBadgeCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            totalBadgeCount > 99
                                ? '99+'
                                : totalBadgeCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class FriendsHubPage extends StatefulWidget {
  final UserSession session;

  const FriendsHubPage({
    super.key,
    required this.session,
  });

  @override
  State<FriendsHubPage> createState() => _FriendsHubPageState();
}

class _FriendsHubPageState extends State<FriendsHubPage> {
  final TextEditingController searchController = TextEditingController();
  bool isSearching = false;
  List<FriendUser> searchResults = [];

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _searchUsers() async {
    final keyword = searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          searchResults = [];
          isSearching = false;
        });
        return;
      }

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .limit(80)
          .get();

      final currentEmail = (currentUser.email ?? '').trim().toLowerCase();

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentUserData = currentUserDoc.data() ?? {};
      final currentPlayerId =
          (currentUserData['playerId'] ?? '').toString().trim().toLowerCase();

      final blockedUids = List<String>.from(
        currentUserData['blockedUids'] ?? [],
      );

      final friendshipsSnap = await FirebaseFirestore.instance
          .collection('friendships')
          .where('memberUids', arrayContains: currentUser.uid)
          .get();

      final Set<String> friendUids = <String>{};

      for (final doc in friendshipsSnap.docs) {
        final data = doc.data();
        final memberUids = List<String>.from(data['memberUids'] ?? []);

        for (final uid in memberUids) {
          if (uid != currentUser.uid) {
            friendUids.add(uid);
          }
        }
      }

      final results = <FriendUser>[];

      for (final doc in usersSnap.docs) {
        final user = FriendUser.fromDoc(doc);

        final uid = user.uid.trim();
        final displayName = user.displayName.trim().toLowerCase();
        final shortName = user.shortName.trim().toLowerCase();
        final email = user.email.trim().toLowerCase();
        final playerId = user.playerId.trim().toLowerCase();

        if (uid.isEmpty) continue;

        if (uid == currentUser.uid) continue;

        if (blockedUids.contains(uid)) continue;

        if (friendUids.contains(uid)) continue;

        final targetData = doc.data();
        final targetBlocked = List<String>.from(targetData['blockedUids'] ?? []);

        if (targetBlocked.contains(currentUser.uid)) continue;

        final matched = displayName.contains(keyword) ||
            shortName.contains(keyword) ||
            email.contains(keyword) ||
            playerId.contains(keyword);

        if (!matched) continue;

        if (email == currentEmail) continue;
        if (playerId == currentPlayerId) continue;

        results.add(user);
      }

      if (!mounted) return;

      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        searchResults = [];
        isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed')),
      );
    }
  }

  Future<void> _sendRequest(FriendUser user) async {
    try {
      await sendFriendRequest(targetUser: user);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${user.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteFriendship(Map<String, dynamic> friendshipData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userA = Map<String, dynamic>.from(friendshipData['userA'] ?? {});
    final userB = Map<String, dynamic>.from(friendshipData['userB'] ?? {});
    final otherUser =
        (userA['uid'] ?? '').toString() == currentUser.uid ? userB : userA;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete friend'),
          content: Text(
            'Remove ${(otherUser['displayName'] ?? 'this friend').toString()} from your friend list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await deleteFriend(
      currentUid: currentUser.uid,
      otherUid: (otherUser['uid'] ?? '').toString(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend deleted')),
    );
  }

  Future<void> _blockFriend(Map<String, dynamic> friendshipData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userA = Map<String, dynamic>.from(friendshipData['userA'] ?? {});
    final userB = Map<String, dynamic>.from(friendshipData['userB'] ?? {});
    final otherUser =
        (userA['uid'] ?? '').toString() == currentUser.uid ? userB : userA;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to blacklist'),
          content: Text(
            'Block ${(otherUser['displayName'] ?? 'this user').toString()}? After blocking, this user will not appear in search.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await blockUser(
      currentUid: currentUser.uid,
      targetUid: (otherUser['uid'] ?? '').toString(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User added to blacklist')),
    );
  }

  Future<void> _unblockUser(FriendUser user) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove from blacklist'),
          content: Text(
            'Remove ${user.displayName} from blacklist?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await unblockUser(
      currentUid: currentUser.uid,
      targetUid: user.uid,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from blacklist')),
    );
  }

  Future<void> _editFriendNickname(Map<String, dynamic> friendshipData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = (friendshipData['chatId'] ?? '').toString();
    final nicknames = Map<String, dynamic>.from(friendshipData['nicknames'] ?? {});
    final initialNickname = (nicknames[currentUser.uid] ?? '').toString();

    final controller = TextEditingController(text: initialNickname);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit friend name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'Enter a custom name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    await saveFriendNickname(
      chatId: chatId,
      currentUid: currentUser.uid,
      nickname: controller.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend name updated')),
    );
  }

  Future<void> _openChatFromFriendship(
    Map<String, dynamic> friendshipData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userA = Map<String, dynamic>.from(friendshipData['userA'] ?? {});
    final userB = Map<String, dynamic>.from(friendshipData['userB'] ?? {});
    final nicknames = Map<String, dynamic>.from(
      friendshipData['nicknames'] ?? {},
    );

    final otherUser =
        (userA['uid'] ?? '').toString() == currentUser.uid ? userB : userA;

    final otherUid = (otherUser['uid'] ?? '').toString().trim();

    final blocked = await isBlockedEitherWay(
      currentUid: currentUser.uid,
      otherUid: otherUid,
    );

    if (blocked) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user is not available'),
        ),
      );
      return;
    }

    final myNickname = (nicknames[currentUser.uid] ?? '').toString().trim();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          chatId: (friendshipData['chatId'] ?? '').toString(),
          otherUid: otherUid,
          otherDisplayName: (otherUser['displayName'] ?? 'Chat').toString(),
          otherPhotoUrl: (otherUser['photoUrl'] ?? '').toString(),
          otherNickname: myNickname,
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search player',
                hintText: 'Name / email / player ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                suffixIcon: IconButton(
                  onPressed: isSearching ? null : _searchUsers,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _searchUsers(),
            ),
            const SizedBox(height: 12),
            if (isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No search results yet',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              Column(
                children: searchResults.map((user) {
                  final imageProvider =
                      (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty)
                          ? NetworkImage(user.photoUrl!)
                          : null;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${user.email}\nID: ${user.playerId}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed: user.uid == currentUid
                          ? null
                          : () => _sendRequest(user),
                      child: Text(
                        user.uid == currentUid ? 'You' : 'Add',
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequests() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUid', isEqualTo: currentUid)
          .where('status', whereIn: ['pending', 'ignored'])
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incoming Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Text(
                    'No incoming requests',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? 'pending')
                          .toString()
                          .trim();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage:
                              ((data['fromPhotoUrl'] ?? '').toString().trim().isNotEmpty)
                                  ? NetworkImage(
                                      (data['fromPhotoUrl'] ?? '').toString().trim(),
                                    )
                                  : null,
                          child: ((data['fromPhotoUrl'] ?? '').toString().trim().isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          (data['fromDisplayName'] ?? 'Unknown').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          (data['fromShortName'] ?? '').toString(),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (status == 'pending')
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await ignoreFriendRequest(data);
                                  } catch (_) {}
                                },
                                child: const Text('Ignore'),
                              ),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await rejectFriendRequest(data);
                                } catch (_) {}
                              },
                              child: const Text('Reject'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await acceptFriendRequest(data);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst('Exception: ', ''),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                status == 'ignored' ? 'Add' : 'Accept',
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final currentUserData = userSnapshot.data?.data() ?? {};
            final blockedUids = List<String>.from(
              currentUserData['blockedUids'] ?? [],
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('friendships')
                  .where('memberUids', arrayContains: currentUid)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = [...(snapshot.data?.docs ?? [])]
                    .where((doc) {
                      final data = doc.data();

                      final userA =
                          Map<String, dynamic>.from(data['userA'] ?? {});
                      final userB =
                          Map<String, dynamic>.from(data['userB'] ?? {});

                      final otherUser =
                          (userA['uid'] ?? '').toString() == currentUid
                              ? userB
                              : userA;

                      final otherUid =
                          (otherUser['uid'] ?? '').toString().trim();

                      return !blockedUids.contains(otherUid);
                    })
                    .toList()
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();

                    final aTime = aData['updatedAt'];
                    final bTime = bData['updatedAt'];

                    final aMillis =
                        aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
                    final bMillis =
                        bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

                    return bMillis.compareTo(aMillis);
                  });

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No friends yet',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Friends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...docs.map((doc) {
                      final data = doc.data();

                      final userA =
                          Map<String, dynamic>.from(data['userA'] ?? {});
                      final userB =
                          Map<String, dynamic>.from(data['userB'] ?? {});
                      final nicknames =
                          Map<String, dynamic>.from(data['nicknames'] ?? {});

                      final otherUser =
                          (userA['uid'] ?? '').toString() == currentUid
                              ? userB
                              : userA;

                      final otherUid =
                          (otherUser['uid'] ?? '').toString().trim();

                      final nickname =
                          (nicknames[currentUid] ?? '').toString().trim();

                      final displayName = nickname.isNotEmpty
                          ? nickname
                          : (otherUser['displayName'] ?? 'Friend').toString();

                      final subtitleName =
                          (otherUser['displayName'] ?? '').toString().trim();

                      final avatarData = resolveAvatarFieldsFromMap(otherUser);

                      final imageUrl = avatarData['photoUrl'] as String;
                      final avatarType = avatarData['avatarType'] as String;
                      final avatarIcon = avatarData['avatarIcon'] as String;
                      final avatarBgColor = avatarData['avatarBgColor'] as int;

                      final chatId = (data['chatId'] ?? '').toString();

                      return FutureBuilder<bool>(
                        future: isBlockedEitherWay(
                          currentUid: currentUid,
                          otherUid: otherUid,
                        ),
                        builder: (context, blockedSnapshot) {
                          if (blockedSnapshot.data == true) {
                            return const SizedBox();
                          }

                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('direct_chats')
                                .doc(chatId)
                                .snapshots(),
                            builder: (context, chatSnapshot) {
                              final chatData = chatSnapshot.data?.data() ?? {};
                              final unreadCounts = Map<String, dynamic>.from(
                                chatData['unreadCounts'] ?? {},
                              );
                              final rawUnread = unreadCounts[currentUid] ?? 0;

                              final unreadCount = rawUnread is int
                                  ? rawUnread
                                  : int.tryParse(rawUnread.toString()) ?? 0;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () => _openChatFromFriendship(data),

                                leading: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(otherUid)
                                      .get(),
                                  builder: (context, userSnap) {
                                    final userData = userSnap.data?.data() ?? otherUser;

                                    final avatar = resolveAvatarSnapshotFromMap(userData);

                                    return buildAppAvatar(
                                      radius: 20,
                                      avatar: avatar,
                                      displayName: displayName,
                                      iconSize: 18,
                                      textSize: 14,
                                    );
                                  },
                                ),

                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 22,
                                          minHeight: 22,
                                        ),
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : unreadCount.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: subtitleName.isNotEmpty &&
                                        subtitleName != displayName
                                    ? Text(subtitleName)
                                    : Text(
                                        unreadCount > 0
                                            ? '$unreadCount unread message${unreadCount > 1 ? 's' : ''}'
                                            : 'Tap to open chat',
                                      ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'chat') {
                                      await _openChatFromFriendship(data);
                                    } else if (value == 'edit_name') {
                                      await _editFriendNickname(data);
                                    } else if (value == 'delete_friend') {
                                      await _deleteFriendship(data);
                                    } else if (value == 'block') {
                                      await _blockFriend(data);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'chat',
                                      child: Text('Open chat'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit_name',
                                      child: Text('Edit name'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete_friend',
                                      child: Text('Delete friend'),
                                    ),
                                    PopupMenuItem(
                                      value: 'block',
                                      child: Text('Blacklist'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, snapshot) {
            final currentUserDocSnapshot = snapshot.connectionState ==
                    ConnectionState.waiting
                ? null
                : null;

            final data = snapshot.data?.data() ?? {};
            final blockedUids = List<String>.from(data['blockedUids'] ?? []);

            if (blockedUids.isEmpty) {
              return const SizedBox();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blocked Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                ...blockedUids.map((uid) {
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get(),
                    builder: (context, userSnapshot) {
                      final userData = userSnapshot.data?.data() ?? {};
                      final displayName =
                          (userData['displayName'] ?? 'User').toString();
                      final shortName =
                          (userData['shortName'] ?? '').toString().trim();
                      final photoUrl =
                          (userData['photoUrl'] ?? '').toString().trim();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? const Icon(Icons.block)
                              : null,
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: shortName.isNotEmpty
                            ? Text(shortName)
                            : null,
                        trailing: TextButton(
                          onPressed: () async {
                            await unblockUser(
                              currentUid: currentUid,
                              targetUid: uid,
                            );
                          },
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Friends & Chat',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSearchCard(),
            const SizedBox(height: 14),
            _buildIncomingRequests(),
            const SizedBox(height: 14),
            _buildFriendsList(),
            const SizedBox(height: 14),
            _buildBlockedUsersList(),
          ],
        ),
      ),
    );
  }
}

class UnreadChatIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const UnreadChatIconButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty) {
      return IconButton(
        onPressed: onTap,
        tooltip: 'Friends & Chat',
        icon: const Icon(Icons.people_alt_outlined),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('direct_chats')
          .where('memberUids', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadTotal = 0;

        for (final doc in snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          final data = doc.data();
          final unreadCounts =
              Map<String, dynamic>.from(data['unreadCounts'] ?? {});
          final count = (unreadCounts[currentUid] ?? 0);

          if (count is int) {
            unreadTotal += count;
          } else {
            unreadTotal += int.tryParse(count.toString()) ?? 0;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onTap,
              tooltip: 'Friends & Chat',
              icon: const Icon(Icons.people_alt_outlined),
            ),
            if (unreadTotal > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadTotal > 99 ? '99+' : unreadTotal.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class FriendChatButton extends StatelessWidget {
  final String chatId;
  final VoidCallback onTap;

  const FriendChatButton({
    super.key,
    required this.chatId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Chat'),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('direct_chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        final data = snapshot.data?.data();
        if (data != null) {
          final unreadCounts =
              Map<String, dynamic>.from(data['unreadCounts'] ?? {});
          final rawCount = unreadCounts[currentUid] ?? 0;

          if (rawCount is int) {
            unreadCount = rawCount;
          } else {
            unreadCount = int.tryParse(rawCount.toString()) ?? 0;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(unreadCount > 0 ? 'Chat ($unreadCount)' : 'Chat'),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String otherDisplayName;
  final String otherPhotoUrl;
  final String? otherNickname;

  const ChatRoomPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherDisplayName,
    required this.otherPhotoUrl,
    this.otherNickname,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController chatSearchController = TextEditingController();

  bool isSending = false;
  bool isSearchMode = false;
  String chatKeyword = '';

  @override
  void initState() {
    super.initState();
    _markChatAsRead();
  }

  Future<void> _markChatAsRead() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('direct_chats')
          .doc(widget.chatId)
          .set({
        'unreadCounts': {
          currentUid: 0,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isSending = true;
    });

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentData = currentUserDoc.data() ?? {};
      final senderName =
          (currentData['displayName'] ?? currentUser.displayName ?? 'User')
              .toString();

      final senderPhotoUrl =
          (currentData['photoUrl'] ?? currentUser.photoURL ?? '').toString();

      final chatRef = FirebaseFirestore.instance
          .collection('direct_chats')
          .doc(widget.chatId);

      final messageRef = chatRef.collection('messages').doc();

      final chatSnap = await chatRef.get();
      final chatData = chatSnap.data() ?? {};
      final unreadCounts =
          Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});

      final otherUnreadRaw = unreadCounts[widget.otherUid] ?? 0;
      final otherUnread = otherUnreadRaw is int
          ? otherUnreadRaw
          : int.tryParse(otherUnreadRaw.toString()) ?? 0;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(messageRef, {
          'messageId': messageRef.id,
          'chatId': widget.chatId,
          'senderUid': currentUser.uid,
          'senderName': senderName,
          'senderPhotoUrl': senderPhotoUrl,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(chatRef, {
          'chatId': widget.chatId,
          'type': 'direct',
          'memberUids': [currentUser.uid, widget.otherUid],
          'lastMessage': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSenderUid': currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCounts': {
            currentUser.uid: 0,
            widget.otherUid: otherUnread + 1,
          },
        }, SetOptions(merge: true));

        tx.set(
          FirebaseFirestore.instance.collection('friendships').doc(widget.chatId),
          {
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      messageController.clear();

      await _markChatAsRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }

    if (mounted) {
      setState(() {
        isSending = false;
      });
    }
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied')),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    chatSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final titleText =
        (widget.otherNickname ?? '').trim().isNotEmpty
            ? widget.otherNickname!.trim()
            : widget.otherDisplayName;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: isSearchMode
            ? TextField(
                controller: chatSearchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search chat history',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    onPressed: () {
                      chatSearchController.clear();
                      setState(() {
                        chatKeyword = '';
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    chatKeyword = value.trim().toLowerCase();
                  });
                },
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.otherPhotoUrl.trim().isNotEmpty
                        ? NetworkImage(widget.otherPhotoUrl.trim())
                        : null,
                    child: widget.otherPhotoUrl.trim().isEmpty
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isSearchMode = !isSearchMode;
                if (!isSearchMode) {
                  chatSearchController.clear();
                  chatKeyword = '';
                }
              });
            },
            icon: Icon(
              isSearchMode ? Icons.close : Icons.search,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('direct_chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final rawDocs = snapshot.data?.docs ?? [];

                  final docs = rawDocs.where((doc) {
                    if (chatKeyword.isEmpty) return true;

                    final data = doc.data();
                    final text = (data['text'] ?? '').toString().toLowerCase();
                    final senderName =
                        (data['senderName'] ?? '').toString().toLowerCase();

                    return text.contains(chatKeyword) ||
                        senderName.contains(chatKeyword);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        chatKeyword.isEmpty
                            ? 'No messages yet'
                            : 'No matching messages',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final isMine =
                          (data['senderUid'] ?? '').toString() == currentUid;
                      final text = (data['text'] ?? '').toString();

                      return Align(
                        alignment:
                            isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _copyMessage(text),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMine)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      (data['senderName'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                SelectableText(
                                  text,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isSending ? null : _sendMessage,
                    child: Text(isSending ? '...' : 'Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TableDetailPage extends StatefulWidget {
  final UserSession session;
  final TableData table;
  final String tableId;

  const TableDetailPage({
    super.key,
    required this.session,
    required this.table,
    required this.tableId,
  });

  @override
  State<TableDetailPage> createState() => _TableDetailPageState();
}

class _TableDetailPageState extends State<TableDetailPage> {
  late final DocumentReference<Map<String, dynamic>> tableDocRef;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tableSub;
  bool _isShowingSeatSwapDialog = false;

  int? movingSeatIndex;
  String? movingPlayerName;
  String? _lastWaitingEventKey;
  bool _isShowingWaitingLeaveSnack = false;
  bool _isShowingFillSeatDialog = false;

  @override
  void initState() {
    super.initState();
    tableDocRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(widget.tableId);

    _tableSub = tableDocRef.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      _listenForPendingSeatSwap(data);
    });
  }

  @override
  void dispose() {
    _tableSub?.cancel();
    super.dispose();
  }

  Future<T> _runTableTransaction<T>(
    Future<T> Function(
      Transaction tx,
      DocumentSnapshot<Map<String, dynamic>> snap,
      Map<String, dynamic> data,
    ) action,
  ) async {
    final db = FirebaseFirestore.instance;

    return db.runTransaction<T>((tx) async {
      final snap = await tx.get(tableDocRef);

      if (!snap.exists) {
        throw Exception('Table not found');
      }

      final data = snap.data();
      if (data == null) {
        throw Exception('Table data missing');
      }

      return action(tx, snap, data);
    });
  }

  Never _txFail(String message) {
    throw Exception(message);
  }

  String _cleanError(Object e) {
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _listenForPendingSeatSwap(Map<String, dynamic> data) async {
    if (!mounted) return;
    if (_isShowingSeatSwapDialog) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pendingRaw = data['pendingSeatSwap'];
    if (pendingRaw is! Map) return;

    final pendingSwap = Map<String, dynamic>.from(pendingRaw);
    final targetUid = (pendingSwap['targetUid'] ?? '').toString().trim();

    if (targetUid.isEmpty || targetUid != user.uid) return;

    _isShowingSeatSwapDialog = true;

    final requesterName =
        (pendingSwap['requesterName'] ?? 'Another player').toString().trim();

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Seat Swap Request'),
        content: Text(
          '$requesterName wants to swap seats with you.\n\nDo you agree?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree'),
          ),
        ],
      ),
    );

    _isShowingSeatSwapDialog = false;

    if (!mounted) return;

    if (approved == true) {
      await _approvePendingSeatSwap(pendingSwap);
    } else {
      await _declinePendingSeatSwap();
    }
  }

  void _handleWaitingListEvent(Map<String, dynamic> data) {
    if (!isHost) return;

    final rawEvent = data['lastWaitingListEvent'];
    if (rawEvent is! Map) return;

    final event = Map<String, dynamic>.from(rawEvent);
    final type = (event['type'] ?? '').toString().trim();
    final name = (event['name'] ?? '').toString().trim();
    final at = event['at']?.toString() ?? '';

    final key = '$type|$name|$at';
    if (_lastWaitingEventKey == key) return;

    _lastWaitingEventKey = key;

    if (type == 'leave' && name.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (_isShowingWaitingLeaveSnack) return;

        _isShowingWaitingLeaveSnack = true;
        _showSnack('$name left the waiting list');

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _isShowingWaitingLeaveSnack = false;
        });

        final table = TableData.fromMap(data);
        final hasOpenSeat = table.seats.any((seat) => seat.isOpen);
        final hasWaitingPlayers = table.waitingList.isNotEmpty;

        if (hasOpenSeat && hasWaitingPlayers) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          await _promptFillFirstOpenSeatFromWaitingList();
        }
      });
    }
  }

  Future<void> _promptFillFirstOpenSeatFromWaitingList() async {
    if (_isShowingFillSeatDialog) return;

    final snapshot = await tableDocRef.get();
    final data = snapshot.data();
    if (data == null) return;

    final table = TableData.fromMap(data);

    if (table.waitingList.isEmpty) return;

    final firstOpenSeatIndex = table.seats.indexWhere((seat) => seat.isOpen);
    if (firstOpenSeatIndex == -1) return;

    _isShowingFillSeatDialog = true;

    try {
      await _promptFillSeatFromWaitingList(firstOpenSeatIndex);
    } finally {
      _isShowingFillSeatDialog = false;
    }
  }

  Map<String, dynamic> _buildMetaUpdate() {
    return {
      'updatedAt': FieldValue.serverTimestamp(),
      'version': FieldValue.increment(1),
    };
  }

  Future<List<String?>> _getSeatNamesFromFirestore() async {
    final snapshot = await tableDocRef.get();
    final data = snapshot.data();
    return List<String?>.from(data?['seats'] ?? []);
  }

  Future<List<String>> _getWaitingListFromFirestore() async {
    final snapshot = await tableDocRef.get();
    final data = snapshot.data();
    return List<String>.from(data?['waitingList'] ?? []);
  }

  bool get isHost => widget.session.role == UserRole.host;

  bool get isSuperAdmin =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ==
      superAdminEmail.toLowerCase();

  bool get isTableCreator =>
      widget.table.createdByUid == FirebaseAuth.instance.currentUser?.uid;

  bool get canManageThisTable => isTableCreator || isSuperAdmin;

  bool get isEffectiveHost => canManageThisTable;

  bool _isCurrentUserInTableFromTable(TableData table) {
    final myName = widget.session.name.trim();
    return table.seats.any((seat) => (seat.playerName ?? '').trim() == myName);
  }

  Future<void> _startMovePlayer(int seatIndex) async {
    if (!canManageThisTable) {
      _showSnack('Only the table creator can move players');
      return;
    }

    final seatNames = await _getSeatNamesFromFirestore();

    if (seatIndex < 0 || seatIndex >= seatNames.length) {
      _showSnack('Invalid seat');
      return;
    }

    final playerName = seatNames[seatIndex];
    if (playerName == null) return;

    setState(() {
      movingSeatIndex = seatIndex;
      movingPlayerName = playerName;
    });

    _showSnack('Tap another seat to move or swap');
  }

  Future<Map<String, dynamic>?> _showSelectPlayerDialog() async {
    final searchController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> allPlayers = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredPlayers = [];

    try {
      final currentUid = (currentUser?.uid ?? '').trim();

      final tableSnap = await tableDocRef.get();
      final tableData = tableSnap.data() ?? {};

      final rawSeats = List<dynamic>.from(tableData['seats'] ?? []);
      final waitingList = List<dynamic>.from(tableData['waitingList'] ?? []);

      final seatedUids = <String>{};
      final seatedPlayerIds = <String>{};
      final seatedNames = <String>{};

      for (final raw in rawSeats) {
        Map<String, dynamic> seat = {};

        if (raw is Map<String, dynamic>) {
          seat = Map<String, dynamic>.from(raw);
        } else if (raw is Map) {
          seat = Map<String, dynamic>.from(raw);
        }

        final uid = (seat['playerUid'] ?? '').toString().trim();
        final playerId =
            (seat['playerId'] ?? '').toString().trim().toLowerCase();

        if (uid.isNotEmpty) {
          seatedUids.add(uid);
        }

        if (playerId.isNotEmpty) {
          seatedPlayerIds.add(playerId);
        }

        final identityKey = _seatIdentityKey(seat);
        if (identityKey.isNotEmpty) {
          seatedNames.add(identityKey);
        }
      }

      final waitingIdentityKeys = waitingList
          .map((e) => normalizeWaitingEntry(e))
          .map((e) => _waitingIdentityKey(e))
          .where((e) => e.isNotEmpty)
          .toSet();

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true);

      if (currentUid.isNotEmpty) {
        query = query.where('grantedHostIds', arrayContains: currentUid);
      }

      final snapshot = await query.limit(200).get();

      int sortScore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final data = doc.data();
        final selectedCount = (data['hostPickCount'] ?? 0) is int
            ? (data['hostPickCount'] ?? 0) as int
            : int.tryParse((data['hostPickCount'] ?? '0').toString()) ?? 0;
        return selectedCount;
      }

      allPlayers = snapshot.docs.where((doc) {
        final data = doc.data();

        final uid = doc.id.trim();
        final displayName =
            (data['displayName'] ?? '').toString().trim();
        final shortName =
            (data['shortName'] ?? '').toString().trim();
        final playerId =
            (data['playerId'] ?? '').toString().trim().toLowerCase();

        if (uid.isEmpty) {
          return false;
        }

        if (currentUid.isNotEmpty && uid == currentUid) {
          return false;
        }

        if (seatedUids.contains(uid)) {
          return false;
        }

        if (playerId.isNotEmpty && seatedPlayerIds.contains(playerId)) {
          return false;
        }

        final identityKey = [
          uid.toLowerCase(),
          playerId,
          displayName.toLowerCase(),
          shortName.toLowerCase(),
        ].where((e) => e.isNotEmpty).join('|');

        if (identityKey.isNotEmpty && seatedNames.contains(identityKey)) {
          return false;
        }

        if (identityKey.isNotEmpty && waitingIdentityKeys.contains(identityKey)) {
          return false;
        }

        return true;
      }).toList();

      allPlayers.sort((a, b) {
        final scoreA = sortScore(a);
        final scoreB = sortScore(b);

        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }

        final tsA = a.data()['lastHostPickedAt'];
        final tsB = b.data()['lastHostPickedAt'];

        final timeA = tsA is Timestamp ? tsA.millisecondsSinceEpoch : 0;
        final timeB = tsB is Timestamp ? tsB.millisecondsSinceEpoch : 0;

        if (timeA != timeB) {
          return timeB.compareTo(timeA);
        }

        final nameA =
            ((a.data()['shortName'] ?? a.data()['displayName'] ?? '')
                    .toString())
                .toLowerCase();

        final nameB =
            ((b.data()['shortName'] ?? b.data()['displayName'] ?? '')
                    .toString())
                .toLowerCase();

        return nameA.compareTo(nameB);
      });

      filteredPlayers = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
        allPlayers,
      );
    } catch (e) {
      _showSnack('Failed to load players');
      return null;
    }

    if (!mounted) {
      return null;
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void runFilter(String rawKeyword) {
              final keyword = rawKeyword.trim().toLowerCase();

              final result = allPlayers.where((doc) {
                final data = doc.data();

                final displayName =
                    (data['displayName'] ?? '').toString().toLowerCase();
                final lastName =
                    (data['lastName'] ?? '').toString().toLowerCase();
                final shortName =
                    (data['shortName'] ?? '').toString().toLowerCase();
                final playerId =
                    (data['playerId'] ?? '').toString().toLowerCase();
                final email =
                    (data['email'] ?? '').toString().toLowerCase();

                if (keyword.isEmpty) {
                  return true;
                }

                return displayName.contains(keyword) ||
                    lastName.contains(keyword) ||
                    shortName.contains(keyword) ||
                    playerId.contains(keyword) ||
                    email.contains(keyword);
              }).toList();

              result.sort((a, b) {
                final scoreA = ((a.data()['hostPickCount'] ?? 0) is int)
                    ? (a.data()['hostPickCount'] ?? 0) as int
                    : int.tryParse(
                            (a.data()['hostPickCount'] ?? '0').toString(),
                          ) ??
                        0;

                final scoreB = ((b.data()['hostPickCount'] ?? 0) is int)
                    ? (b.data()['hostPickCount'] ?? 0) as int
                    : int.tryParse(
                            (b.data()['hostPickCount'] ?? '0').toString(),
                          ) ??
                        0;

                if (scoreA != scoreB) {
                  return scoreB.compareTo(scoreA);
                }

                final tsA = a.data()['lastHostPickedAt'];
                final tsB = b.data()['lastHostPickedAt'];

                final timeA =
                    tsA is Timestamp ? tsA.millisecondsSinceEpoch : 0;
                final timeB =
                    tsB is Timestamp ? tsB.millisecondsSinceEpoch : 0;

                if (timeA != timeB) {
                  return timeB.compareTo(timeA);
                }

                final nameA =
                    ((a.data()['shortName'] ?? a.data()['displayName'] ?? '')
                            .toString())
                        .toLowerCase();

                final nameB =
                    ((b.data()['shortName'] ?? b.data()['displayName'] ?? '')
                            .toString())
                        .toLowerCase();

                return nameA.compareTo(nameB);
              });

              setDialogState(() {
                filteredPlayers = result;
              });
            }

            return AlertDialog(
              title: const Text('Select Player'),
              content: SizedBox(
                width: 420,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: runFilter,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search player',
                        hintText: 'Name or email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredPlayers.isEmpty
                          ? const Center(
                              child: Text('No available players found'),
                            )
                          : ListView.separated(
                              itemCount: filteredPlayers.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final player = filteredPlayers[index];
                                final data =
                                    Map<String, dynamic>.from(player.data());

                                final name =
                                    (data['displayName'] ?? '').toString().trim();

                                return ListTile(
                                  title: Text(name),
                                  onTap: () {
                                    Navigator.pop(context, {
                                      'uid': player.id,
                                      'displayName': (data['displayName'] ?? '')
                                          .toString()
                                          .trim(),
                                      'lastName': (data['lastName'] ?? '')
                                          .toString()
                                          .trim(),
                                      'shortName': (data['shortName'] ?? '')
                                          .toString()
                                          .trim(),
                                      'photoUrl': (data['photoUrl'] ?? '')
                                          .toString()
                                          .trim(),
                                      'playerId': (data['playerId'] ?? '')
                                          .toString()
                                          .trim(),
                                      'avatarType': (data['avatarType'] ?? 'photo')
                                          .toString()
                                          .trim(),
                                      'avatarIcon': (data['avatarIcon'] ?? 'person')
                                          .toString()
                                          .trim(),
                                      'avatarBgColor': data['avatarBgColor'] is int
                                          ? data['avatarBgColor'] as int
                                          : 0xFF2563EB,
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showReserveGuestDialog(
    List<SeatReservation> seats,
  ) async {
    final firstNameController = TextEditingController();
    final lastInitialController = TextEditingController();
  
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final firstName = firstNameController.text.trim();
            final normalizedFirst = firstName.toLowerCase();

            final hasDuplicate = normalizedFirst.isNotEmpty &&
                seats.any((s) {
                  final playerName = _extractFirstName((s.playerName ?? '').trim());
                  final playerShortName = _extractFirstName((s.playerShortName ?? '').trim());
                  final reservedName = _extractFirstName((s.reservedForName ?? '').trim());
                  final reservedShortName =
                      _extractFirstName((s.reservedForShortName ?? '').trim());
            
                  return playerName == normalizedFirst ||
                      playerShortName == normalizedFirst ||
                      reservedName == normalizedFirst ||
                      reservedShortName == normalizedFirst;
                });
  
            final lastInitial = lastInitialController.text.trim().toUpperCase();
  
            final canReserve = firstName.isNotEmpty &&
                (!hasDuplicate || lastInitial.isNotEmpty);
  
            return AlertDialog(
              title: const Text('Reserve Seat'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: firstNameController,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      hintText: 'Enter first name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hasDuplicate) ...[
                    TextField(
                      controller: lastInitialController,
                      onChanged: (_) => setLocalState(() {}),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 1,
                      decoration: const InputDecoration(
                        labelText: 'Last initial',
                        hintText: 'Example: A',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This name already exists at the table. Please add last initial, like Joe A or Joe B.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No duplicate name at this table.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: canReserve
                      ? () {
                          final cleanFirst = firstNameController.text.trim();
                          final cleanLastInitial =
                              lastInitialController.text.trim().toUpperCase();
  
                          final shortName = cleanLastInitial.isNotEmpty
                              ? '$cleanFirst $cleanLastInitial'
                              : cleanFirst;
  
                          Navigator.pop(context, {
                            'reservedForName': cleanFirst,
                            'reservedForShortName': shortName,
                            'reservedForUid': null,
                            'reservedForPlayerId': null,
                            'reservedArrived': false,
                          });
                        }
                      : null,
                  child: const Text('Reserve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _reserveSeatForGuest(int seatIndex) async {
    if (!canManageThisTable) {
      _showSnack('Only the table creator can reserve seats');
      return;
    }

    final tableRef =
        FirebaseFirestore.instance.collection('tables').doc(widget.tableId);

    try {
      final previewSnap = await tableRef.get();
      if (!previewSnap.exists) {
        _showSnack('Table not found');
        return;
      }

      final previewData = previewSnap.data() as Map<String, dynamic>;
      final previewTable = TableData.fromMap(previewData);

      final result = await _showReserveGuestDialog(previewTable.seats);
      if (result == null) return;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(tableRef);
        if (!snap.exists) {
          throw Exception('Table not found');
        }

        final data = snap.data() as Map<String, dynamic>;
        final table = TableData.fromMap(data);

        if (seatIndex < 0 || seatIndex >= table.seats.length) {
          throw Exception('Invalid seat');
        }

        final seat = table.seats[seatIndex];

        if (seat.isOccupied) {
          throw Exception('Seat is already occupied');
        }

        if (seat.isReserved) {
          throw Exception('Seat is already reserved');
        }

        seat.playerName = null;
        seat.playerLastName = null;
        seat.playerShortName = null;
        seat.playerUid = null;
        seat.playerPhotoUrl = null;
        seat.playerId = null;

        seat.reservedForName =
            (result['reservedForName'] ?? '').toString().trim();
        seat.reservedForShortName =
            (result['reservedForShortName'] ?? '').toString().trim();
        seat.reservedForUid =
            (result['reservedForUid'] ?? '').toString().trim();
        seat.reservedForPlayerId =
            (result['reservedForPlayerId'] ?? '').toString().trim();

        seat.reservedArrived = false;
        seat.arrived = null;

        tx.update(tableRef, {
          'seats': table.seats.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      _showSnack('Seat reserved');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _claimReservedSeat(int seatIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login first');
      return;
    }

    final tableRef =
        FirebaseFirestore.instance.collection('tables').doc(widget.tableId);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final displayName =
          (userData['displayName'] ?? user.displayName ?? 'User')
              .toString()
              .trim();

      final lastName =
          (userData['lastName'] ?? '').toString().trim();

      final shortName =
          (userData['shortName'] ?? displayName).toString().trim();

      final playerId =
          (userData['playerId'] ?? '').toString().trim();

      final rawPhotoUrl =
          (userData['photoUrl'] ?? user.photoURL ?? '').toString().trim();

      final avatarType =
          (userData['avatarType'] ?? 'photo').toString().trim().isEmpty
              ? 'photo'
              : (userData['avatarType'] ?? 'photo').toString().trim();

      final avatarIcon =
          (userData['avatarIcon'] ?? 'person').toString().trim().isEmpty
              ? 'person'
              : (userData['avatarIcon'] ?? 'person').toString().trim();

      final avatarBgColor = userData['avatarBgColor'] is int
          ? userData['avatarBgColor'] as int
          : 0xFF2563EB;

      final seatPhotoUrl =
          avatarType == 'virtual'
              ? null
              : (rawPhotoUrl.isEmpty ? null : rawPhotoUrl);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(tableRef);
        final data = snapshot.data();
        if (data == null) {
          throw Exception('Table not found');
        }

        final table = TableData.fromMap(data);

        if (seatIndex < 0 || seatIndex >= table.seats.length) {
          throw Exception('Invalid seat');
        }

        final seat = table.seats[seatIndex];

        if (!seat.isReserved) {
          throw Exception('This seat is no longer reserved');
        }

        final reservedForMe =
            ((seat.reservedForUid ?? '').trim().isNotEmpty &&
                (seat.reservedForUid ?? '').trim() == user.uid) ||
            (playerId.isNotEmpty &&
                (seat.reservedForPlayerId ?? '').trim().isNotEmpty &&
                (seat.reservedForPlayerId ?? '').trim() == playerId) ||
            ((seat.reservedForName ?? '').trim().isNotEmpty &&
                (seat.reservedForName ?? '').trim().toLowerCase() ==
                    displayName.toLowerCase());

        if (!reservedForMe) {
          throw Exception('This reserved seat is not for you');
        }

        final alreadySeated = table.seats.asMap().entries.any((entry) {
          if (entry.key == seatIndex) return false;

          final otherSeat = entry.value;
          final otherUid = (otherSeat.playerUid ?? '').trim();
          final otherPlayerId = (otherSeat.playerId ?? '').trim();

          return otherUid == user.uid ||
              (playerId.isNotEmpty && otherPlayerId == playerId);
        });

        if (alreadySeated) {
          throw Exception('You already joined this table');
        }

        table.seats[seatIndex] = SeatReservation.fromMap(
          buildOccupiedSeatMap(
            playerName: displayName,
            playerShortName: shortName.isEmpty ? displayName : shortName,
            playerUid: user.uid,
            playerId: playerId,
            playerPhotoUrl: seatPhotoUrl,
            playerLastName: lastName,
            playerAvatarType: avatarType,
            playerAvatarIcon: avatarIcon,
            playerAvatarBgColor: avatarBgColor,
            arrived: seat.reservedArrived == true,
          ),
        );

        transaction.update(tableRef, {
          'seats': table.seats.map((e) => e.toMap()).toList(),
          ..._buildMetaUpdate(),
        });
      });

      _showSnack('Seat claimed');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _assignSelectedPlayerToSeat(int seatIndex) async {
    final selectedPlayer = await _showSelectPlayerDialog();
    if (selectedPlayer == null) return;
  
    final tableRef =
        FirebaseFirestore.instance.collection('tables').doc(widget.tableId);
  
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(tableRef);
        final data = snapshot.data();
        if (data == null) return;
  
        final table = TableData.fromMap(data);
        if (seatIndex < 0 || seatIndex >= table.seats.length) return;
  
        final seat = table.seats[seatIndex];
  
        final selectedAvatarType =
            (selectedPlayer['avatarType'] ?? 'photo').toString().trim().isEmpty
                ? 'photo'
                : (selectedPlayer['avatarType'] ?? 'photo').toString().trim();

        final selectedAvatarIcon =
            (selectedPlayer['avatarIcon'] ?? 'person').toString().trim().isEmpty
                ? 'person'
                : (selectedPlayer['avatarIcon'] ?? 'person').toString().trim();

        final selectedAvatarBgColor =
            selectedPlayer['avatarBgColor'] is int
                ? selectedPlayer['avatarBgColor'] as int
                : 0xFF2563EB;

        table.seats[seatIndex] = SeatReservation.fromMap(
          buildOccupiedSeatMap(
            playerName: (selectedPlayer['displayName'] ?? '').toString().trim(),
            playerShortName: (selectedPlayer['shortName'] ?? '').toString().trim(),
            playerUid: (selectedPlayer['uid'] ?? '').toString().trim(),
            playerId: (selectedPlayer['playerId'] ?? '').toString().trim(),
            playerPhotoUrl: selectedAvatarType == 'virtual'
                ? null
                : (selectedPlayer['photoUrl'] ?? '').toString().trim(),
            playerLastName: (selectedPlayer['lastName'] ?? '').toString().trim(),
            playerAvatarType: selectedAvatarType,
            playerAvatarIcon: selectedAvatarIcon,
            playerAvatarBgColor: selectedAvatarBgColor,
            arrived: false,
          ),
        );
  
        transaction.update(tableRef, {
          'seats': table.seats.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
  
      final selectedUid = (selectedPlayer['uid'] ?? '').toString().trim();
  
      if (selectedUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(selectedUid)
            .set({
          'hostPickCount': FieldValue.increment(1),
          'lastHostPickedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
  
      _showSnack('Player assigned to seat');
    } catch (e) {
      _showSnack('Failed to assign player');
    }
  }

  Future<void> _clearSeatByHost(int seatIndex) async {
    final tableRef =
        FirebaseFirestore.instance.collection('tables').doc(widget.tableId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(tableRef);
        final data = snapshot.data();
        if (data == null) return;

        final table = TableData.fromMap(data);
        if (seatIndex < 0 || seatIndex >= table.seats.length) return;

        final seat = table.seats[seatIndex];

        seat.playerUid = null;
        seat.playerName = null;
        seat.playerLastName = null;
        seat.playerShortName = null;
        seat.playerPhotoUrl = null;
        seat.playerId = null;

        seat.reservedForName = null;
        seat.reservedForShortName = null;
        seat.reservedForUid = null;
        seat.reservedForPlayerId = null;

        transaction.update(tableRef, {
          'seats': table.seats.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      _showSnack('Player removed from seat');

      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      await _promptFillSeatFromWaitingList(seatIndex);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to remove player');
    }
  }

  Future<void> _removeReserveByHost(int seatIndex) async {
    final tableRef =
        FirebaseFirestore.instance.collection('tables').doc(widget.tableId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(tableRef);
        final data = snapshot.data();
        if (data == null) return;

        final table = TableData.fromMap(data);
        if (seatIndex < 0 || seatIndex >= table.seats.length) return;

        final seat = table.seats[seatIndex];

        seat.reservedForName = null;
        seat.reservedForShortName = null;
        seat.reservedForUid = null;
        seat.reservedForPlayerId = null;
        seat.reservedArrived = null;

        transaction.update(tableRef, {
          'seats': table.seats.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _showSnack('Reservation removed');
    } catch (e) {
      _showSnack('Failed to remove reservation');
    }
  }

  void _cancelMovePlayer() {
    setState(() {
      movingSeatIndex = null;
      movingPlayerName = null;
    });
  }

  Future<void> _completeMovePlayer(int targetSeatIndex) async {
    if (!canManageThisTable) return;
    if (movingSeatIndex == null) return;
  
    final fromIndex = movingSeatIndex!;
  
    try {
      bool targetWasOpen = false;
      bool sourceWasReserved = false;
  
      await _runTableTransaction<void>((tx, snap, data) async {
        final seatList = normalizeSeatMaps(data['seats']);
  
        if (fromIndex < 0 || fromIndex >= seatList.length) {
          _txFail('Invalid source seat');
        }
  
        if (targetSeatIndex < 0 || targetSeatIndex >= seatList.length) {
          _txFail('Invalid target seat');
        }
  
        if (fromIndex == targetSeatIndex) {
          return;
        }
  
        final fromSeat = Map<String, dynamic>.from(seatList[fromIndex]);
        final targetSeat = Map<String, dynamic>.from(seatList[targetSeatIndex]);
  
        final fromPlayerName = (fromSeat['playerName'] ?? '').toString().trim();
        final fromPlayerUid = (fromSeat['playerUid'] ?? '').toString().trim();
        final fromReservedName =
            (fromSeat['reservedForName'] ?? '').toString().trim();
        final fromReservedUid =
            (fromSeat['reservedForUid'] ?? '').toString().trim();
        final fromReservedPlayerId =
            (fromSeat['reservedForPlayerId'] ?? '').toString().trim();
  
        final targetPlayerName =
            (targetSeat['playerName'] ?? '').toString().trim();
        final targetPlayerUid =
            (targetSeat['playerUid'] ?? '').toString().trim();
        final targetReservedName =
            (targetSeat['reservedForName'] ?? '').toString().trim();
        final targetReservedUid =
            (targetSeat['reservedForUid'] ?? '').toString().trim();
        final targetReservedPlayerId =
            (targetSeat['reservedForPlayerId'] ?? '').toString().trim();
  
        final fromHasOccupied =
            fromPlayerName.isNotEmpty || fromPlayerUid.isNotEmpty;
        final fromHasReserved =
            fromReservedName.isNotEmpty ||
            fromReservedUid.isNotEmpty ||
            fromReservedPlayerId.isNotEmpty;
  
        if (!fromHasOccupied && !fromHasReserved) {
          _txFail('Source seat is empty');
        }
  
        final targetHasOccupied =
            targetPlayerName.isNotEmpty || targetPlayerUid.isNotEmpty;
        final targetHasReserved =
            targetReservedName.isNotEmpty ||
            targetReservedUid.isNotEmpty ||
            targetReservedPlayerId.isNotEmpty;
  
        targetWasOpen = !targetHasOccupied && !targetHasReserved;
        sourceWasReserved = !fromHasOccupied && fromHasReserved;
  
        seatList[targetSeatIndex] = fromSeat;
        seatList[fromIndex] = targetSeat;
  
        tx.update(tableDocRef, {
          'seats': seatList,
          ..._buildMetaUpdate(),
        });
      });
  
      if (!mounted) return;
  
      setState(() {
        movingSeatIndex = null;
        movingPlayerName = null;
      });
  
      if (targetWasOpen) {
        _showSnack(
          sourceWasReserved
              ? 'Reserved seat moved successfully'
              : 'Player moved successfully',
        );
      } else {
        _showSnack('Seats swapped successfully');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
      _cancelMovePlayer();
    }
  }

  Future<void> _changeSeatCount(int newCount) async {
    if (!canManageThisTable) {
      _showSnack('Only the table creator can change seat count');
      return;
    }
  
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final rawSeats = List<dynamic>.from(data['seats'] ?? []);
  
        final seatList = rawSeats.map((seat) {
          if (seat is Map<String, dynamic>) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is Map) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is String) {
            return <String, dynamic>{
              'playerName': seat,
              'playerLastName': null,
              'playerShortName': seat,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            };
          }
          return <String, dynamic>{
            'playerName': null,
            'playerLastName': null,
            'playerShortName': null,
            'playerUid': null,
            'playerPhotoUrl': null,
            'playerId': null,
          };
        }).toList();
  
        bool isSeatEmpty(Map<String, dynamic> seat) {
          final playerName = (seat['playerName'] ?? '').toString().trim();
          final playerUid = (seat['playerUid'] ?? '').toString().trim();
          final playerId = (seat['playerId'] ?? '').toString().trim();
  
          return playerName.isEmpty && playerUid.isEmpty && playerId.isEmpty;
        }
  
        if (newCount == seatList.length) {
          return;
        }
  
        if (newCount > seatList.length) {
          // 增加：從最後面補空位
          while (seatList.length < newCount) {
            seatList.add({
              'playerName': null,
              'playerLastName': null,
              'playerShortName': null,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            });
          }
        } else {
          // 遞減：優先刪除最後面的空位
          while (seatList.length > newCount) {
            int removeIndex = -1;
  
            for (int i = seatList.length - 1; i >= 0; i--) {
              final seat = Map<String, dynamic>.from(seatList[i]);
              if (isSeatEmpty(seat)) {
                removeIndex = i;
                break;
              }
            }
  
            if (removeIndex == -1) {
              _txFail(
                'Cannot reduce seat count because there are no empty seats to remove',
              );
            }
  
            seatList.removeAt(removeIndex);
          }
        }
  
        tx.update(tableDocRef, {
          'playerSeatCount': newCount,
          'seats': seatList,
          ..._buildMetaUpdate(),
        });
      });
  
      _showSnack('Seat count updated');
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }



  Future<void> _joinSeatAsCurrentUser(int seatIndex) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnack('User not found');
      return;
    }

    final myUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final myData = myUserDoc.data() ?? {};

    final myName =
        (myData['displayName'] ?? widget.session.name).toString().trim();

    final myShortName =
        (myData['shortName'] ?? widget.session.shortName).toString().trim();

    final myLastName =
        (myData['lastName'] ?? '').toString().trim();

    final myPlayerId =
        (myData['playerId'] ?? '').toString().trim();

    final myPhotoUrl =
        (myData['photoUrl'] ?? user.photoURL ?? '').toString().trim();

    final myAvatarType =
        (myData['avatarType'] ?? 'photo').toString().trim().isEmpty
            ? 'photo'
            : (myData['avatarType'] ?? 'photo').toString().trim();

    final myAvatarIcon =
        (myData['avatarIcon'] ?? 'person').toString().trim().isEmpty
            ? 'person'
            : (myData['avatarIcon'] ?? 'person').toString().trim();

    final myAvatarBgColor = myData['avatarBgColor'] is int
        ? myData['avatarBgColor'] as int
        : 0xFF2563EB;

    final seatPhotoUrl =
        myAvatarType == 'virtual' ? null : (myPhotoUrl.isEmpty ? null : myPhotoUrl);

    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final rawSeats = List<dynamic>.from(data['seats'] ?? []);

        final seatList = rawSeats.map((seat) {
          if (seat is Map<String, dynamic>) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is Map) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is String) {
            return <String, dynamic>{
              'playerName': seat,
              'playerLastName': null,
              'playerShortName': seat,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
              'playerAvatarType': null,
              'playerAvatarIcon': null,
              'playerAvatarBgColor': null,
              'reservedForName': null,
              'reservedForShortName': null,
              'reservedForUid': null,
              'reservedForPlayerId': null,
              'reservedArrived': null,
              'arrived': null,
            };
          }
          return <String, dynamic>{
            'playerName': null,
            'playerLastName': null,
            'playerShortName': null,
            'playerUid': null,
            'playerPhotoUrl': null,
            'playerId': null,
            'playerAvatarType': null,
            'playerAvatarIcon': null,
            'playerAvatarBgColor': null,
            'reservedForName': null,
            'reservedForShortName': null,
            'reservedForUid': null,
            'reservedForPlayerId': null,
            'reservedArrived': null,
            'arrived': null,
          };
        }).toList();

        final waitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        if (seatIndex < 0 || seatIndex >= seatList.length) {
          _txFail('Invalid seat');
        }

        final currentSeat = seatList[seatIndex];

        final currentSeatName =
            (currentSeat['playerName'] ?? '').toString().trim();
        final currentSeatUid =
            (currentSeat['playerUid'] ?? '').toString().trim();
        final currentSeatPlayerId =
            (currentSeat['playerId'] ?? '').toString().trim();

        final reservedName =
            (currentSeat['reservedForName'] ?? '').toString().trim();
        final reservedUid =
            (currentSeat['reservedForUid'] ?? '').toString().trim();
        final reservedPlayerId =
            (currentSeat['reservedForPlayerId'] ?? '').toString().trim();

        final seatAlreadyTaken = currentSeatName.isNotEmpty ||
            currentSeatUid.isNotEmpty ||
            currentSeatPlayerId.isNotEmpty;

        if (seatAlreadyTaken) {
          _txFail('This seat is already taken');
        }

        final seatReservedForSomeoneElse = reservedName.isNotEmpty ||
            reservedUid.isNotEmpty ||
            reservedPlayerId.isNotEmpty;

        final reservedForMe =
            (reservedUid.isNotEmpty && reservedUid == user.uid) ||
            (myPlayerId.isNotEmpty &&
                reservedPlayerId.isNotEmpty &&
                reservedPlayerId == myPlayerId) ||
            (reservedName.isNotEmpty && reservedName == myName);

        if (seatReservedForSomeoneElse && !reservedForMe) {
          _txFail('This seat is reserved');
        }

        final alreadyJoined = seatList.any((seat) {
          final seatUid = (seat['playerUid'] ?? '').toString().trim();
          final seatPlayerId = (seat['playerId'] ?? '').toString().trim();
          return seatUid == user.uid ||
              (myPlayerId.isNotEmpty && seatPlayerId == myPlayerId);
        });

        if (alreadyJoined) {
          _txFail('You already joined this table');
        }

        seatList[seatIndex] = buildOccupiedSeatMap(
          playerName: myName,
          playerShortName: myShortName.isEmpty ? myName : myShortName,
          playerUid: user.uid,
          playerId: myPlayerId,
          playerPhotoUrl: seatPhotoUrl,
          playerLastName: myLastName,
          playerAvatarType: myAvatarType,
          playerAvatarIcon: myAvatarIcon,
          playerAvatarBgColor: myAvatarBgColor,
          arrived: false,
        );

        waitingList.removeWhere((entry) {
          final uid = (entry['uid'] ?? '').toString().trim();
          final playerId = (entry['playerId'] ?? '').toString().trim();
          return uid == user.uid ||
              (myPlayerId.isNotEmpty && playerId == myPlayerId);
        });

        tx.update(tableDocRef, {
          'seats': seatList,
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });

      _showSnack('Joined successfully');
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _cancelCurrentUserSeat(int seatIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    final myName = widget.session.name.trim();
  
    if (user == null) {
      _showSnack('User not found');
      return;
    }
  
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final rawSeats = List<dynamic>.from(data['seats'] ?? []);
  
        final seatList = rawSeats.map((seat) {
          if (seat is Map<String, dynamic>) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is Map) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is String) {
            return {
              'playerName': seat,
              'playerUid': null,
              'playerPhotoUrl': null,
            };
          }
          return {
            'playerName': null,
            'playerUid': null,
            'playerPhotoUrl': null,
          };
        }).toList();
  
        if (seatIndex < 0 || seatIndex >= seatList.length) {
          _txFail('Invalid seat');
        }
  
        final seat = seatList[seatIndex];
        final seatName = (seat['playerName'] ?? '').toString().trim();        
        final seatUid = (seat['playerUid'] ?? '').toString().trim();

        final isMySeat = seatUid == user.uid || seatName == myName;
        if (!isMySeat) {
          _txFail('You can only cancel your own seat');
        }

        seatList[seatIndex] = buildEmptySeatMap();
  
        tx.update(tableDocRef, {
          'seats': seatList,
          ..._buildMetaUpdate(),
        });
      });
  
      if (isHost) {
        await _promptFillSeatFromWaitingList(seatIndex);
      } else {
        _showSnack('Seat cancelled');
      }
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _setDealerName() async {
    if (!canManageThisTable) {
      _showSnack('Only the table creator can set the dealer name');
      return;
    }

    final snapshot = await tableDocRef.get();
    final data = snapshot.data();
    final currentDealerName = data?['dealerName'] as String?;

    final controller = TextEditingController(
      text: currentDealerName ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Dealer Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Dealer Name',
              hintText: 'Leave empty if unknown',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result == null) return;

    try {
      await tableDocRef.update({
        'dealerName': result.isEmpty ? null : result,
        ..._buildMetaUpdate(),
      });
      _showSnack('Dealer updated');
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _reservePlayerAsHost(int seatIndex) async {

    final previewSnap = await tableDocRef.get();

    if (!previewSnap.exists) {
      _showSnack('Table not found');
      return;
    }

    final previewData = previewSnap.data() as Map<String, dynamic>;
    final previewTable = TableData.fromMap(previewData);
    
    final result = await _showReserveGuestDialog(previewTable.seats);

    if (!mounted) return;
    if (result == null) return;

    final reservedName = (result['name'] ?? '').toString().trim();
    final reservedShortName =
        (result['shortName'] ?? reservedName).toString().trim();
    final reservedUid = (result['uid'] ?? '').toString().trim();
    final reservedPlayerId = (result['playerId'] ?? '').toString().trim();

    if (reservedName.isEmpty) {
      _showSnack('Invalid player');
      return;
    }

    try {

      await _runTableTransaction<void>((tx, snap, data) async {

        final seatList = normalizeSeatMaps(data['seats']);

        final waitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        if (seatIndex < 0 || seatIndex >= seatList.length) {
          _txFail('Invalid seat');
        }

        final currentSeat = Map<String, dynamic>.from(seatList[seatIndex]);

        final playerName = (currentSeat['playerName'] ?? '').toString().trim();
        final playerUid = (currentSeat['playerUid'] ?? '').toString().trim();
        final reservedForName =
            (currentSeat['reservedForName'] ?? '').toString().trim();
        final reservedForUid =
            (currentSeat['reservedForUid'] ?? '').toString().trim();
        final reservedForPlayerId =
            (currentSeat['reservedForPlayerId'] ?? '').toString().trim();

        final seatIsOccupied = playerName.isNotEmpty || playerUid.isNotEmpty;
        final seatIsReserved = reservedForName.isNotEmpty ||
            reservedForUid.isNotEmpty ||
            reservedForPlayerId.isNotEmpty;

        if (seatIsOccupied || seatIsReserved) {
          _txFail('This seat is not open');
        }

        final alreadySeated = seatList.any((seat) {
          final seatPlayerUid = (seat['playerUid'] ?? '').toString().trim();
          final seatPlayerId = (seat['playerId'] ?? '').toString().trim();
          final seatPlayerName = (seat['playerName'] ?? '').toString().trim();

          if (reservedUid.isNotEmpty && seatPlayerUid == reservedUid) {
            return true;
          }

          if (reservedPlayerId.isNotEmpty && seatPlayerId == reservedPlayerId) {
            return true;
          }

          if (reservedUid.isEmpty &&
              reservedPlayerId.isEmpty &&
              seatPlayerName.toLowerCase() == reservedName.toLowerCase()) {
            return true;
          }

          return false;
        });

        if (alreadySeated) {
          _txFail('This player is already seated');
        }

        final alreadyReserved = seatList.any((seat) {
          final seatReservedUid = (seat['reservedForUid'] ?? '').toString().trim();
          final seatReservedPlayerId =
              (seat['reservedForPlayerId'] ?? '').toString().trim();
          final seatReservedName =
              (seat['reservedForName'] ?? '').toString().trim();

          if (reservedUid.isNotEmpty && seatReservedUid == reservedUid) {
            return true;
          }

          if (reservedPlayerId.isNotEmpty &&
              seatReservedPlayerId == reservedPlayerId) {
            return true;
          }

          if (reservedUid.isEmpty &&
              reservedPlayerId.isEmpty &&
              seatReservedName.toLowerCase() == reservedName.toLowerCase()) {
            return true;
          }

          return false;
        });

        if (alreadyReserved) {
          _txFail('This player is already reserved');
        }

        seatList[seatIndex] = buildReservedSeatMap(
          reservedForName: reservedName,
          reservedForShortName: reservedShortName,
          reservedForUid: reservedUid,
          reservedForPlayerId: reservedPlayerId,
          reservedArrived: false,
        );

        waitingList.removeWhere((entry) {
          final waitingUid = (entry['uid'] ?? '').toString().trim();
          final waitingPlayerId = (entry['playerId'] ?? '').toString().trim();
          final waitingName = (entry['name'] ?? '').toString().trim();

          if (reservedUid.isNotEmpty && waitingUid == reservedUid) {
            return true;
          }

          if (reservedPlayerId.isNotEmpty &&
              waitingPlayerId == reservedPlayerId) {
            return true;
          }

          if (reservedUid.isEmpty &&
              reservedPlayerId.isEmpty &&
              waitingName.toLowerCase() == reservedName.toLowerCase()) {
            return true;
          }

          return false;
        });

        tx.update(tableDocRef, {
          'seats': seatList,
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });

      });

      if (!mounted) return;

      _showSnack('Seat reserved successfully');

    } catch (e) {

      if (!mounted) return;

      _showSnack(_cleanError(e));

    }

  }

  Future<void> _removePlayerAsHost(int seatIndex) async {
  
    try {
  
      await _runTableTransaction<void>((tx, snap, data) async {
  
        final seats = normalizeSeatMaps(data['seats']);
  
        if (seatIndex < 0 || seatIndex >= seats.length) {
          _txFail('Invalid seat');
        }
  
        final seat = Map<String, dynamic>.from(seats[seatIndex]);
  
        final playerName = (seat['playerName'] ?? '').toString().trim();
        final playerUid = (seat['playerUid'] ?? '').toString().trim();
        final reservedForName = (seat['reservedForName'] ?? '').toString().trim();
        final reservedForUid = (seat['reservedForUid'] ?? '').toString().trim();
        final reservedForPlayerId =
            (seat['reservedForPlayerId'] ?? '').toString().trim();
  
        final hasOccupiedPlayer = playerName.isNotEmpty || playerUid.isNotEmpty;
        final hasReservedPlayer = reservedForName.isNotEmpty ||
            reservedForUid.isNotEmpty ||
            reservedForPlayerId.isNotEmpty;
  
        if (!hasOccupiedPlayer && !hasReservedPlayer) {
          _txFail('Seat already empty');
        }
  
        seats[seatIndex] = buildEmptySeatMap();
  
        tx.update(tableDocRef, {
          'seats': seats,
          ..._buildMetaUpdate(),
        });
  
      });
  
      if (!mounted) return;
  
      await _promptFillSeatFromWaitingList(seatIndex);
  
    } catch (e) {
  
      if (!mounted) return;
  
      _showSnack(_cleanError(e));
  
    }
  
  }

  Future<Map<String, String>?> _showAddWaitingGuestDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
  
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Waiting List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Guest Name',
                  hintText: 'Example: Joe',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Invitation Code / Player ID (optional)',
                  hintText: 'Example: AB12CD34',
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Leave code empty for guest without account.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final playerId = codeController.text.trim().toUpperCase();
  
                if (name.isEmpty) return;
  
                Navigator.pop(context, {
                  'name': name,
                  'shortName': name,
                  'playerId': playerId,
                });
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToWaitingList() async {
    final user = FirebaseAuth.instance.currentUser;
    final myName = widget.session.name.trim();
    final myShortName = widget.session.shortName.trim();
  
    if (user == null) {
      _showSnack('User not found');
      return;
    }
  
    if (myName.isEmpty) {
      _showSnack('Name not found');
      return;
    }
  
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final rawSeats = List<dynamic>.from(data['seats'] ?? []);
        final rawWaitingList = List<dynamic>.from(data['waitingList'] ?? []);
  
        final waitingList = rawWaitingList
            .map((e) => normalizeWaitingEntry(e))
            .toList();
  
        final myUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
  
        final myData = myUserDoc.data() ?? {};

        final myPlayerId =
            (myUserDoc.data()?['playerId'] ?? '').toString().trim();
  
        final seatList = rawSeats.map((seat) {
          if (seat is Map<String, dynamic>) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is Map) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is String) {
            return {
              'playerName': seat,
              'playerLastName': null,
              'playerShortName': seat,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            };
          }
          return {
            'playerName': null,
            'playerLastName': null,
            'playerShortName': null,
            'playerUid': null,
            'playerPhotoUrl': null,
            'playerId': null,
          };
        }).toList();
  
        final alreadySeated = seatList.any((seat) {
          final seatUid = (seat['playerUid'] ?? '').toString().trim();
          final seatPlayerId = (seat['playerId'] ?? '').toString().trim();
          return seatUid == user.uid ||
              (myPlayerId.isNotEmpty && seatPlayerId == myPlayerId);
        });
  
        if (alreadySeated) {
          _txFail('You are already seated');
        }
  
        final alreadyWaiting = waitingList.any((entry) {
          final uid = (entry['uid'] ?? '').toString().trim();
          final playerId = (entry['playerId'] ?? '').toString().trim();
          return uid == user.uid ||
              (myPlayerId.isNotEmpty && playerId == myPlayerId);
        });
  
        if (alreadyWaiting) {
          _txFail('Already in waiting list');
        }
  
        waitingList.add({
          'uid': user.uid,
          'name': myName,
          'shortName': myShortName.isNotEmpty ? myShortName : myName,
          'playerId': myPlayerId,
        });
 
        tx.update(tableDocRef, {
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });
  
      _showSnack('Added to waiting list');
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _hostAddToWaitingList() async {
    if (!canManageThisTable) {
      _showSnack('Only host can add others to waiting list');
      return;
    }
  
    final result = await _showAddWaitingGuestDialog();
    if (result == null) return;
  
    final guestName = (result['name'] ?? '').trim();
    final guestShortName = (result['shortName'] ?? guestName).trim();
    final guestPlayerId = (result['playerId'] ?? '').trim().toUpperCase();
  
    if (guestName.isEmpty) {
      _showSnack('Guest name is required');
      return;
    }
  
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final rawSeats = List<dynamic>.from(data['seats'] ?? []);
        final rawWaitingList = List<dynamic>.from(data['waitingList'] ?? []);
  
        final waitingList = rawWaitingList
            .map((e) => normalizeWaitingEntry(e))
            .toList();
  
        final seatList = rawSeats.map((seat) {
          if (seat is Map<String, dynamic>) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is Map) {
            return Map<String, dynamic>.from(seat);
          }
          if (seat is String) {
            return {
              'playerName': seat,
              'playerLastName': null,
              'playerShortName': seat,
              'playerUid': null,
              'playerPhotoUrl': null,
              'playerId': null,
            };
          }
          return {
            'playerName': null,
            'playerLastName': null,
            'playerShortName': null,
            'playerUid': null,
            'playerPhotoUrl': null,
            'playerId': null,
          };
        }).toList();
  
        final alreadySeated = seatList.any((seat) {
          final seatName = (seat['playerName'] ?? '').toString().trim();
          final seatPlayerId = (seat['playerId'] ?? '').toString().trim().toUpperCase();
  
          if (guestPlayerId.isNotEmpty) {
            return seatPlayerId == guestPlayerId;
          }
  
          return seatName.toLowerCase() == guestName.toLowerCase();
        });
  
        if (alreadySeated) {
          _txFail('This player is already seated');
        }
  
        final alreadyWaiting = waitingList.any((entry) {
          final entryName = (entry['name'] ?? '').toString().trim();
          final entryPlayerId = (entry['playerId'] ?? '').toString().trim().toUpperCase();
  
          if (guestPlayerId.isNotEmpty) {
            return entryPlayerId == guestPlayerId;
          }
  
          return entryName.toLowerCase() == guestName.toLowerCase();
        });
  
        if (alreadyWaiting) {
          _txFail('Already in waiting list');
        }
  
        waitingList.add({
          'uid': '',
          'name': guestName,
          'shortName': guestShortName,
          'playerId': guestPlayerId,
          'arrived': false,
        });

        tx.update(tableDocRef, {
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });
  
      _showSnack('Added to waiting list');
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _removeFromWaitingListAt(int index) async {
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final waitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        if (index < 0 || index >= waitingList.length) {
          _txFail('Invalid waiting list index');
        }

        final entry = Map<String, dynamic>.from(waitingList[index]);

        if (!_canCurrentUserRemoveWaitingEntry(entry)) {
          _txFail('You can only remove yourself from waiting list');
        }

        waitingList.removeAt(index);

        tx.update(tableDocRef, {
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });

      if (!mounted) return;
      _showSnack('Removed from waiting list');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _moveWaitingToSeat(
    int waitingIndex,
    int targetSeatIndex,
  ) async {
    if (!canManageThisTable) {
      _showSnack('Only the table creator can move waiting players');
      return;
    }

    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final seats = normalizeSeatMaps(data['seats']);

        final waitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        if (waitingIndex < 0 || waitingIndex >= waitingList.length) {
          _txFail('Invalid waiting list index');
        }

        if (targetSeatIndex < 0 || targetSeatIndex >= seats.length) {
          _txFail('Invalid seat');
        }

        final targetSeat = Map<String, dynamic>.from(seats[targetSeatIndex]);

        final playerName = (targetSeat['playerName'] ?? '').toString().trim();
        final playerUid = (targetSeat['playerUid'] ?? '').toString().trim();
        final reservedName =
            (targetSeat['reservedForName'] ?? '').toString().trim();
        final reservedUid =
            (targetSeat['reservedForUid'] ?? '').toString().trim();
        final reservedPlayerId =
            (targetSeat['reservedForPlayerId'] ?? '').toString().trim();

        final seatIsReserved = reservedName.isNotEmpty ||
            reservedUid.isNotEmpty ||
            reservedPlayerId.isNotEmpty;

        final seatIsOccupied = playerName.isNotEmpty || playerUid.isNotEmpty;

        if (seatIsReserved || seatIsOccupied) {
          _txFail('Target seat is not open');
        }

        final entry = Map<String, dynamic>.from(
          waitingList.removeAt(waitingIndex),
        );

        final waitingName = (entry['name'] ?? '').toString().trim();
        final waitingShortName =
            (entry['shortName'] ?? waitingName).toString().trim();
        final waitingUid = (entry['uid'] ?? '').toString().trim();
        final waitingPlayerId = (entry['playerId'] ?? '').toString().trim();
        final waitingArrived = entry['arrived'] == true;

        String waitingPhotoUrl = '';
        String waitingAvatarType = 'photo';
        String waitingAvatarIcon = 'person';
        int waitingAvatarBgColor = 0xFF2563EB;

        if (waitingUid.isNotEmpty) {
          final waitingUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(waitingUid)
              .get();

          final waitingUserData = waitingUserDoc.data() ?? {};

          waitingPhotoUrl =
              (waitingUserData['photoUrl'] ?? '').toString().trim();

          waitingAvatarType =
              (waitingUserData['avatarType'] ?? 'photo').toString().trim().isEmpty
                  ? 'photo'
                  : (waitingUserData['avatarType'] ?? 'photo').toString().trim();

          waitingAvatarIcon =
              (waitingUserData['avatarIcon'] ?? 'person').toString().trim().isEmpty
                  ? 'person'
                  : (waitingUserData['avatarIcon'] ?? 'person').toString().trim();

          waitingAvatarBgColor = waitingUserData['avatarBgColor'] is int
              ? waitingUserData['avatarBgColor'] as int
              : 0xFF2563EB;
        }

        seats[targetSeatIndex] = buildOccupiedSeatMap(
          playerName: waitingName,
          playerShortName: waitingShortName,
          playerUid: waitingUid,
          playerId: waitingPlayerId,
          playerPhotoUrl: waitingPhotoUrl,
          playerAvatarType: waitingAvatarType,
          playerAvatarIcon: waitingAvatarIcon,
          playerAvatarBgColor: waitingAvatarBgColor,
          arrived: waitingArrived,
        );

        tx.update(tableDocRef, {
          'seats': seats,
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });

      if (!mounted) return;
      _showSnack('Moved to Seat ${targetSeatIndex + 1}');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _toggleWaitingArrived(int index) async {
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final waitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        if (index < 0 || index >= waitingList.length) {
          _txFail('Invalid waiting list index');
        }

        final entry = Map<String, dynamic>.from(waitingList[index]);

        if (!_canCurrentUserToggleWaitingArrived(entry)) {
          _txFail('You can only change your own arrived status');
        }

        waitingList[index]['arrived'] = !(entry['arrived'] == true);

        tx.update(tableDocRef, {
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _toggleArrivedAtSeat(int seatIndex) async {
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final seats = normalizeSeatMaps(data['seats']);

        if (seatIndex < 0 || seatIndex >= seats.length) {
          _txFail('Invalid seat');
        }

        final seat = Map<String, dynamic>.from(seats[seatIndex]);

        final playerName = (seat['playerName'] ?? '').toString().trim();
        final playerUid = (seat['playerUid'] ?? '').toString().trim();

        if (playerName.isEmpty && playerUid.isEmpty) {
          _txFail('Seat is empty');
        }

        if (!_canCurrentUserToggleSeatArrived(seat)) {
          _txFail('You can only change your own arrived status');
        }

        final currentArrived = seat['arrived'] == true;

        seat['arrived'] = !currentArrived;
        seats[seatIndex] = seat;

        tx.update(tableDocRef, {
          'seats': seats,
          ..._buildMetaUpdate(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  bool _canCurrentUserToggleWaitingArrived(Map<String, dynamic> entry) {
    if (canManageThisTable) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final entryUid = (entry['uid'] ?? '').toString().trim();
    return entryUid.isNotEmpty && entryUid == user.uid;
  }

  bool _canCurrentUserRemoveWaitingEntry(Map<String, dynamic> entry) {
    if (canManageThisTable) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final entryUid = (entry['uid'] ?? '').toString().trim();

    if (entryUid.isNotEmpty) {
      return entryUid == user.uid;
    }

    return false;
  }

  bool _canCurrentUserToggleSeatArrived(Map<String, dynamic> seat) {
    if (canManageThisTable) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final seatUid = (seat['playerUid'] ?? '').toString().trim();
    if (seatUid.isNotEmpty) {
      return seatUid == user.uid;
    }

    final myName = widget.session.name.trim().toLowerCase();
    final myShortName = widget.session.shortName.trim().toLowerCase();

    final seatName = (seat['playerName'] ?? '').toString().trim().toLowerCase();
    final seatShortName =
        (seat['playerShortName'] ?? '').toString().trim().toLowerCase();

    return seatName == myName || seatShortName == myShortName;
  }

  Future<bool> _isReservedSeatMine(Map<String, dynamic> seat) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final reservedUid = (seat['reservedForUid'] ?? '').toString().trim();
    final reservedPlayerId =
        (seat['reservedForPlayerId'] ?? '').toString().trim();

    if (reservedUid.isNotEmpty && reservedUid == user.uid) {
      return true;
    }

    if (reservedPlayerId.isEmpty) {
      return false;
    }

    final myUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final myPlayerId =
        (myUserDoc.data()?['playerId'] ?? '').toString().trim();

    return myPlayerId.isNotEmpty && reservedPlayerId == myPlayerId;
  }

  String buildWaitingLabel(Map<String, dynamic> player, int index) {
    final name = (player['name'] ?? '').toString().trim();
    final playerId = (player['playerId'] ?? '').toString().trim();
  
    final suffix = playerId.isNotEmpty ? '($playerId)' : '(Guest)';
  
    return '${index + 1}. $name $suffix';
  }

  Future<int?> _showPickOpenSeatDialog() async {
    final snap = await tableDocRef.get();
    final data = snap.data();
    final seats = normalizeSeatMaps(data?['seats']);

    final openSeatIndexes = <int>[];

    for (int i = 0; i < seats.length; i++) {
      final seat = Map<String, dynamic>.from(seats[i]);

      final playerName = (seat['playerName'] ?? '').toString().trim();
      final playerUid = (seat['playerUid'] ?? '').toString().trim();
      final reservedName = (seat['reservedForName'] ?? '').toString().trim();
      final reservedUid = (seat['reservedForUid'] ?? '').toString().trim();
      final reservedPlayerId =
          (seat['reservedForPlayerId'] ?? '').toString().trim();

      final isReserved = reservedName.isNotEmpty ||
          reservedUid.isNotEmpty ||
          reservedPlayerId.isNotEmpty;

      final isOccupied = playerName.isNotEmpty || playerUid.isNotEmpty;
      final isOpen = !isOccupied && !isReserved;

      if (isOpen) {
        openSeatIndexes.add(i);
      }
    }

    if (openSeatIndexes.isEmpty) {
      if (!mounted) return null;
      _showSnack('No open seats available');
      return null;
    }

    if (!mounted) return null;

    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              for (final seatIndex in openSeatIndexes)
                ListTile(
                  leading: const Icon(Icons.event_seat_outlined),
                  title: Text('Seat ${seatIndex + 1}'),
                  onTap: () => Navigator.pop(context, seatIndex),
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleReservedSeatArrived(int seatIndex) async {
    try {
      final rawSeat = await _getSeatMapAt(seatIndex);

      final canToggle = canManageThisTable || await _isReservedSeatMine(rawSeat);
      if (!canToggle) {
        _showSnack('You cannot update this reserved player');
        return;
      }

      await _runTableTransaction<void>((tx, snap, data) async {
        final seats = normalizeSeatMaps(data['seats']);

        if (seatIndex < 0 || seatIndex >= seats.length) {
          _txFail('Invalid seat');
        }

        final seat = Map<String, dynamic>.from(seats[seatIndex]);

        final reservedName = (seat['reservedForName'] ?? '').toString().trim();
        final reservedUid = (seat['reservedForUid'] ?? '').toString().trim();
        final reservedPlayerId =
            (seat['reservedForPlayerId'] ?? '').toString().trim();

        final isReserved = reservedName.isNotEmpty ||
            reservedUid.isNotEmpty ||
            reservedPlayerId.isNotEmpty;

        if (!isReserved) {
          _txFail('This seat is not reserved');
        }

        final arrived = seat['reservedArrived'] == true;
        seat['reservedArrived'] = !arrived;
        seats[seatIndex] = seat;

        tx.update(tableDocRef, {
          'seats': seats,
          ..._buildMetaUpdate(),
        });
      });

      if (!mounted) return;
      _showSnack('Reserved status updated');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Future<Map<String, dynamic>> _getSeatMapAt(int seatIndex) async {
    final snap = await tableDocRef.get();
    final data = snap.data();
    final seats = normalizeSeatMaps(data?['seats']);

    if (seatIndex < 0 || seatIndex >= seats.length) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(seats[seatIndex]);
  }

  Future<void> _promptFillSeatFromWaitingList(int seatIndex) async {
    final waitingList = await _getWaitingListFromFirestore();
    if (!mounted) return;
    if (waitingList.isEmpty) return;

    final nextPlayer = normalizeWaitingEntry(waitingList.first);
    final nextPlayerName =
        (nextPlayer['shortName'] ?? nextPlayer['name'] ?? '')
            .toString()
            .trim();

    final shouldFill = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fill Open Seat'),
          content: Text(
            'Move $nextPlayerName from waiting list to this seat?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (shouldFill != true) return;

    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final seats = normalizeSeatMaps(data['seats']);

        final latestWaitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        if (seatIndex < 0 || seatIndex >= seats.length) {
          _txFail('Invalid seat');
        }

        if (latestWaitingList.isEmpty) {
          _txFail('Waiting list is empty');
        }

        final currentSeat = Map<String, dynamic>.from(seats[seatIndex]);

        final currentPlayerName =
            (currentSeat['playerName'] ?? '').toString().trim();
        final currentPlayerUid =
            (currentSeat['playerUid'] ?? '').toString().trim();
        final currentPlayerId =
            (currentSeat['playerId'] ?? '').toString().trim();
        final currentReservedName =
            (currentSeat['reservedForName'] ?? '').toString().trim();
        final currentReservedUid =
            (currentSeat['reservedForUid'] ?? '').toString().trim();
        final currentReservedPlayerId =
            (currentSeat['reservedForPlayerId'] ?? '').toString().trim();

        final seatOccupied = currentPlayerName.isNotEmpty ||
            currentPlayerUid.isNotEmpty ||
            currentPlayerId.isNotEmpty;

        final seatReserved = currentReservedName.isNotEmpty ||
            currentReservedUid.isNotEmpty ||
            currentReservedPlayerId.isNotEmpty;

        if (seatOccupied || seatReserved) {
          _txFail('This seat is no longer open');
        }

        final nextEntry = latestWaitingList.removeAt(0);

        final waitingName =
            (nextEntry['name'] ?? '').toString().trim();
        final waitingShortName =
            (nextEntry['shortName'] ?? waitingName).toString().trim();
        final waitingUid =
            (nextEntry['uid'] ?? '').toString().trim();
        final waitingPlayerId =
            (nextEntry['playerId'] ?? '').toString().trim();
        final waitingArrived = nextEntry['arrived'] == true;

        String? playerPhotoUrl;
        String? playerLastName;
        String? playerAvatarType;
        String? playerAvatarIcon;
        int? playerAvatarBgColor;

        if (waitingUid.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(waitingUid)
              .get();

          final userData = userDoc.data() ?? {};

          playerLastName =
              (userData['lastName'] ?? '').toString().trim();

          final rawPhotoUrl =
              (userData['photoUrl'] ?? '').toString().trim();

          final resolvedAvatarType =
              (userData['avatarType'] ?? 'photo').toString().trim().isEmpty
                  ? 'photo'
                  : (userData['avatarType'] ?? 'photo').toString().trim();

          final resolvedAvatarIcon =
              (userData['avatarIcon'] ?? 'person').toString().trim().isEmpty
                  ? 'person'
                  : (userData['avatarIcon'] ?? 'person').toString().trim();

          final resolvedAvatarBgColor = userData['avatarBgColor'] is int
              ? userData['avatarBgColor'] as int
              : 0xFF2563EB;

          playerAvatarType = resolvedAvatarType;
          playerAvatarIcon = resolvedAvatarIcon;
          playerAvatarBgColor = resolvedAvatarBgColor;
          playerPhotoUrl =
              resolvedAvatarType == 'virtual'
                  ? null
                  : (rawPhotoUrl.isEmpty ? null : rawPhotoUrl);
        }

        seats[seatIndex] = buildOccupiedSeatMap(
          playerName: waitingName,
          playerShortName:
              waitingShortName.isEmpty ? waitingName : waitingShortName,
          playerUid: waitingUid,
          playerId: waitingPlayerId,
          playerPhotoUrl: playerPhotoUrl,
          playerLastName: playerLastName,
          playerAvatarType: playerAvatarType,
          playerAvatarIcon: playerAvatarIcon,
          playerAvatarBgColor: playerAvatarBgColor,
          arrived: waitingArrived,
        );

        tx.update(tableDocRef, {
          'seats': seats,
          'waitingList': latestWaitingList,
          ..._buildMetaUpdate(),
        });
      });

      if (!mounted) return;
      _showSnack('Seat filled from waiting list');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _requestSeatSwap({
    required int fromSeatIndex,
    required int toSeatIndex,
    required Map<String, dynamic> fromSeat,
    required Map<String, dynamic> toSeat,
  }) async {
    final requesterUid = (fromSeat['playerUid'] ?? '').toString().trim();
    final requesterName =
        (fromSeat['playerShortName'] ?? fromSeat['playerName'] ?? '')
            .toString()
            .trim();
    final targetUid = (toSeat['playerUid'] ?? '').toString().trim();
    final targetName =
        (toSeat['playerShortName'] ?? toSeat['playerName'] ?? '')
            .toString()
            .trim();

    if (requesterUid.isEmpty || targetUid.isEmpty) {
      _showSnack('Only seated users can swap');
      return;
    }

    await tableDocRef.set({
      'pendingSeatSwap': {
        'fromSeatIndex': fromSeatIndex,
        'toSeatIndex': toSeatIndex,
        'requesterUid': requesterUid,
        'requesterName': requesterName,
        'targetUid': targetUid,
        'targetName': targetName,
        'createdAt': FieldValue.serverTimestamp(),
      },
      ..._buildMetaUpdate(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    _showSnack('Swap request sent to $targetName');
  }

  Future<void> _approvePendingSeatSwap(Map<String, dynamic> swap) async {
    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final seats = normalizeSeatMaps(data['seats']);
        final pendingRaw = data['pendingSeatSwap'];

        if (pendingRaw is! Map) {
          _txFail('No pending swap');
        }

        final pending = Map<String, dynamic>.from(pendingRaw);

        final fromSeatIndex = (pending['fromSeatIndex'] ?? -1) as int;
        final toSeatIndex = (pending['toSeatIndex'] ?? -1) as int;

        if (fromSeatIndex < 0 || fromSeatIndex >= seats.length) {
          _txFail('Invalid source seat');
        }
        if (toSeatIndex < 0 || toSeatIndex >= seats.length) {
          _txFail('Invalid target seat');
        }

        final fromSeat = Map<String, dynamic>.from(seats[fromSeatIndex]);
        final toSeat = Map<String, dynamic>.from(seats[toSeatIndex]);

        final fromUid = (fromSeat['playerUid'] ?? '').toString().trim();
        final toUid = (toSeat['playerUid'] ?? '').toString().trim();

        if (fromUid.isEmpty || toUid.isEmpty) {
          _txFail('Both seats must still be occupied');
        }

        seats[fromSeatIndex] = toSeat;
        seats[toSeatIndex] = fromSeat;

        tx.update(tableDocRef, {
          'seats': seats,
          'pendingSeatSwap': FieldValue.delete(),
          ..._buildMetaUpdate(),
        });
      });

      if (!mounted) return;
      _showSnack('Seat swap completed');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _declinePendingSeatSwap() async {
    await tableDocRef.set({
      'pendingSeatSwap': FieldValue.delete(),
      ..._buildMetaUpdate(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    _showSnack('Seat swap declined');
  }

  Future<void> _onSeatTap(int seatIndex) async {
    final snapshot = await tableDocRef.get();
    final data = snapshot.data();
    final rawSeats = List<dynamic>.from(data?['seats'] ?? []);
  
    final user = FirebaseAuth.instance.currentUser;
    final myName = widget.session.name.trim();

    final seatList = rawSeats.map((seat) {
      if (seat is Map<String, dynamic>) {
        return Map<String, dynamic>.from(seat);
      }
      if (seat is Map) {
        return Map<String, dynamic>.from(seat);
      }
      if (seat is String) {
        return <String, dynamic>{
          'playerName': seat,
          'playerLastName': null,
          'playerShortName': seat,
          'playerUid': null,
          'playerPhotoUrl': null,
          'playerId': null,
          'reservedForName': null,
          'reservedForShortName': null,
          'reservedForUid': null,
          'reservedForPlayerId': null,
          'reservedArrived': null,
        };
      }
      return <String, dynamic>{
        'playerName': null,
        'playerLastName': null,
        'playerShortName': null,
        'playerUid': null,
        'playerPhotoUrl': null,
        'playerId': null,
        'reservedForName': null,
        'reservedForShortName': null,
        'reservedForUid': null,
        'reservedForPlayerId': null,
        'reservedArrived': null,
      };
    }).toList();

    if (seatIndex < 0 || seatIndex >= seatList.length) {
      _showSnack('Invalid seat');
      return;
    }

    final seat = seatList[seatIndex];

    final reservedArrived =
        (seat['reservedArrived'] ?? false) == true;
    final arrived =
        (seat['arrived'] ?? false) == true;
  
    final seatPlayerName = seat['playerName']?.toString().trim() ?? '';
    final seatPlayerUid = seat['playerUid']?.toString().trim() ?? '';

    final reservedName = (seat['reservedForName'] ?? '').toString().trim();
    final reservedUid = (seat['reservedForUid'] ?? '').toString().trim();
    final reservedPlayerId =
        (seat['reservedForPlayerId'] ?? '').toString().trim();

    final seatIsReserved = seatPlayerName.isEmpty &&
        (reservedName.isNotEmpty ||
            reservedUid.isNotEmpty ||
            reservedPlayerId.isNotEmpty);

    final seatIsOpen = seatPlayerName.isEmpty && !seatIsReserved;
  
    if (movingSeatIndex != null) {
      if (seatIndex == movingSeatIndex) {
        _cancelMovePlayer();
        return;
      }
  
      await _completeMovePlayer(seatIndex);
      return;
    }
  
    if (canManageThisTable) {
      if (seatIsReserved) {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: Icon(
                      reservedArrived ? Icons.schedule : Icons.check_circle,
                    ),
                    title: Text(
                      reservedArrived
                          ? 'Mark as unarrived'
                          : 'Mark as arrived',
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      'toggle_reserved_arrived',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_outline),
                    title: const Text('Move / Swap seat'),
                    onTap: () => Navigator.pop(context, 'move'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_remove_outlined),
                    title: const Text('Remove Reserve'),
                    onTap: () => Navigator.pop(context, 'remove_reserve'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Cancel'),
                    onTap: () => Navigator.pop(context, 'cancel'),
                  ),
                ],
              ),
            );
          },
        );

        if (!mounted) return;

        if (action == 'toggle_reserved_arrived') {
          await _toggleReservedSeatArrived(seatIndex);
          return;
        }

        if (action == 'move') {
          setState(() {
            movingSeatIndex = seatIndex;
            movingPlayerName =
                reservedName.isNotEmpty ? reservedName : 'Reserved Seat';
          });
          _showSnack('Tap another seat to move or swap');
          return;
        }

        if (action == 'remove_reserve') {
          await _removeReserveByHost(seatIndex);
          return;
        }

        return;
      }

      if (seatIsOpen) {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Join myself'),
                    onTap: () => Navigator.pop(context, 'join_self'),
                  ),
                  if (canManageThisTable)
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: const Text('Select player'),
                      onTap: () => Navigator.pop(context, 'select_player'),
                    ),
                  if (canManageThisTable)
                    ListTile(
                      leading: const Icon(Icons.bookmark_add_outlined),
                      title: const Text('Reserve for Guest'),
                      onTap: () => Navigator.pop(context, 'reserve_guest'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Cancel'),
                    onTap: () => Navigator.pop(context, 'cancel'),
                  ),
                ],
              ),
            );
          },
        );

        if (!mounted) return;
        if (action == null || action == 'cancel') return;

        if (action == 'select_player') {
          await _assignSelectedPlayerToSeat(seatIndex);
          return;
        }

        if (action == 'reserve_guest') {
          await _reserveSeatForGuest(seatIndex);
          return;
        }

        if (action == 'join_self') {
          await _joinSeatAsCurrentUser(seatIndex);
          return;
        }

        return;
      }

      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(
                    arrived ? Icons.schedule : Icons.check_circle,
                  ),
                  title: Text(
                    arrived ? 'Mark as unarrived' : 'Mark as arrived',
                  ),
                  onTap: () => Navigator.pop(context, 'toggle_arrived'),
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Move / Swap seat'),
                  onTap: () => Navigator.pop(context, 'move'),
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('Remove from seat'),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context, 'cancel'),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted) return;

      if (action == 'toggle_arrived') {
        await _toggleArrivedAtSeat(seatIndex);
        return;
      }

      if (action == 'move') {
        setState(() {
          movingSeatIndex = seatIndex;
          movingPlayerName = seatPlayerName;
        });
        _showSnack('Tap another seat to move or swap');
        return;
      }

      if (action == 'remove') {
        await _clearSeatByHost(seatIndex);
        return;
      }

      return;
    }
  
    // player mode
    String myPlayerId = '';
    if (user != null) {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final myData = myDoc.data() ?? {};
      myPlayerId = (myData['playerId'] ?? '').toString().trim();
    }
  
    final myShortName = widget.session.shortName.trim().toLowerCase();
  
    final reservedShortName =
        (seat['reservedForShortName'] ?? '').toString().trim().toLowerCase();
  
    final matchesReservedSeat = seatIsReserved &&
        ((reservedUid.isNotEmpty && user != null && reservedUid == user.uid) ||
            (reservedPlayerId.isNotEmpty &&
                myPlayerId.isNotEmpty &&
                reservedPlayerId == myPlayerId) ||
            (reservedShortName.isNotEmpty &&
                reservedShortName == myShortName) ||
            (reservedName.isNotEmpty &&
                reservedName.toLowerCase() == myName.toLowerCase()));
  
    if (seatIsReserved) {
      if (matchesReservedSeat) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Claim Reserved Seat'),
            content: Text(
              'This seat is reserved for ${seat['reservedForShortName'] ?? seat['reservedForName'] ?? 'you'}.\n\nIs this you?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, it is me'),
              ),
            ],
          ),
        );
  
        if (confirmed == true) {
          await _claimReservedSeat(seatIndex);
        }
        return;
      }
  
      _showSnack('This seat is reserved for someone else');
      return;
    }
  
    final mySeatIndex = seatList.indexWhere((s) {
      final map = Map<String, dynamic>.from(s);
      final uid = (map['playerUid'] ?? '').toString().trim();
      final name = (map['playerName'] ?? '').toString().trim();

      return (user != null && uid == user.uid) || name == myName;
    });

    if (seatIsOpen) {
      if (mySeatIndex != -1) {
        _showSnack('You are already seated. Leave your current seat first.');
        return;
      }

      await _joinSeatAsCurrentUser(seatIndex);
      return;
    }
  
    final isMySeat =
        (user != null && seatPlayerUid == user.uid) || seatPlayerName == myName;

    if (isMySeat) {
      final canToggleMine = _canCurrentUserToggleSeatArrived(seat);

      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                if (canToggleMine)
                  ListTile(
                    leading: Icon(
                      arrived ? Icons.schedule : Icons.check_circle,
                    ),
                    title: Text(
                      arrived ? 'Mark as unarrived' : 'Mark as arrived',
                    ),
                    onTap: () => Navigator.pop(context, 'toggle_arrived'),
                  ),
                ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('Leave seat'),
                  onTap: () => Navigator.pop(context, 'leave_seat'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context, 'cancel'),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted || action == null || action == 'cancel') return;

      if (action == 'toggle_arrived') {
        await _toggleArrivedAtSeat(seatIndex);
        return;
      }

      if (action == 'leave_seat') {
        await _cancelCurrentUserSeat(seatIndex);
        return;
      }

      return;
    }

    if (mySeatIndex == -1) {
      _showSnack('You must already be seated to request a swap');
      return;
    }

    final mySeat = Map<String, dynamic>.from(seatList[mySeatIndex]);
    final targetSeat = Map<String, dynamic>.from(seat);

    final mySeatUid = (mySeat['playerUid'] ?? '').toString().trim();
    final targetSeatUid = (targetSeat['playerUid'] ?? '').toString().trim();

    if (mySeatUid.isEmpty || targetSeatUid.isEmpty) {
      _showSnack('Only seated players can swap');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Seat Swap'),
        content: Text(
          'Do you want to ask this player to swap seats with you?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _requestSeatSwap(
      fromSeatIndex: mySeatIndex,
      toSeatIndex: seatIndex,
      fromSeat: mySeat,
      toSeat: targetSeat,
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year}  $hour:$minute $ampm';
  }

  Color _seatFillColor({
    required bool isOpen,
    required bool isMine,
    required bool isDealerSeat,
    required bool isSelectedForMove,
    required SeatReservation seat,
  }) {
    if (isDealerSeat) {
      return const Color(0xFFFFF7ED);
    }

    if (isSelectedForMove) {
      return const Color(0xFFE5E7EB);
    }

    if (isMine) {
      return const Color(0xFFDBEAFE);
    }

    final isReserved =
        (seat.playerName?.trim().isEmpty ?? true) &&
        (
          (seat.reservedForName?.trim().isNotEmpty ?? false) ||
          (seat.reservedForUid?.trim().isNotEmpty ?? false) ||
          (seat.reservedForPlayerId?.trim().isNotEmpty ?? false)
        );

    final isArrived = isReserved
        ? (seat.reservedArrived == true)
        : (seat.arrived == true);

    if (isOpen) {
      return const Color(0xFFDCFCE7);
    }

    if (isArrived) {
      return const Color(0xFFEDE9FE);
    }

    return const Color(0xFFFEE2E2);
  }

  Color _seatBorderColor({
    required bool isOpen,
    required bool isMine,
    required bool isDealerSeat,
    required bool isSelectedForMove,
    required SeatReservation seat,
  }) {
    if (isDealerSeat) {
      return const Color(0xFFF97316);
    }

    if (isSelectedForMove) {
      return Colors.black;
    }

    if (isMine) {
      return const Color(0xFF2563EB);
    }

    final isReserved =
        (seat.playerName?.trim().isEmpty ?? true) &&
        (
          (seat.reservedForName?.trim().isNotEmpty ?? false) ||
          (seat.reservedForUid?.trim().isNotEmpty ?? false) ||
          (seat.reservedForPlayerId?.trim().isNotEmpty ?? false)
        );

    final isArrived = isReserved
        ? (seat.reservedArrived == true)
        : (seat.arrived == true);

    if (isOpen) {
      return const Color(0xFF16A34A);
    }

    if (isArrived) {
      return const Color.fromARGB(255, 200, 9, 238);
    }

    return const Color(0xFFDC2626);
  }

  Widget _buildDetailStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha:0.10),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha:0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCard(TableData table, int openCount, int takenCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF183C2E), Color(0xFF214F3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            table.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (table.stakes.isNotEmpty)
                _buildDetailStatChip(
                  icon: Icons.paid_outlined,
                  label: 'Stakes',
                  value: table.stakes,
                  color: const Color(0xFFFFC857),
                ),
              _buildDetailStatChip(
                icon: Icons.event_seat,
                label: 'Taken',
                value: '$takenCount/${table.playerSeatCount}',
                color: const Color(0xFFEF5350),
              ),
              _buildDetailStatChip(
                icon: Icons.chair_alt_outlined,
                label: 'Open',
                value: '$openCount',
                color: const Color(0xFF2E9E5B),
              ),
              _buildDetailStatChip(
                icon: Icons.groups_2_outlined,
                label: 'Waiting',
                value: '${table.waitingList.length}',
                color: const Color(0xFF7E57C2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(table.dateTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (table.location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      table.location,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.casino_outlined,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    table.dealerName?.trim().isNotEmpty == true
                        ? 'Dealer: ${table.dealerName}'
                        : 'Dealer: Not set',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }





  Widget _buildWaitingListCard(TableData table) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_2_outlined),
              SizedBox(width: 8),
              Text(
                'Waiting List',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (table.waitingList.isEmpty)
            const Text(
              'Nobody is waiting yet.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              children: List.generate(table.waitingList.length, (index) {
                final entry = Map<String, dynamic>.from(table.waitingList[index]);
                final label = buildWaitingLabel(entry, index);
                final arrived = entry['arrived'] == true;
          
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    arrived ? 'Arrived' : 'Unarrived',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  onTap: () async {
                    final canToggleMine =
                        _canCurrentUserToggleWaitingArrived(entry);

                    if (!canManageThisTable && !canToggleMine) return;

                    final action = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) {
                        return SafeArea(
                          child: Wrap(
                            children: [
                              if (canToggleMine)
                                ListTile(
                                  leading: Icon(
                                    arrived ? Icons.schedule : Icons.check_circle,
                                  ),
                                  title: Text(
                                    arrived
                                        ? 'Mark as unarrived'
                                        : 'Mark as arrived',
                                  ),
                                  onTap: () => Navigator.pop(context, 'arrived'),
                                ),
                              if (canManageThisTable)
                                ListTile(
                                  leading: const Icon(Icons.drive_file_move_outline),
                                  title: const Text('Move / swap seat'),
                                  onTap: () => Navigator.pop(context, 'move'),
                                ),
                              if (_canCurrentUserRemoveWaitingEntry(entry))
                                ListTile(
                                  leading: const Icon(Icons.person_remove),
                                  title: Text(
                                    canManageThisTable
                                        ? 'Remove from waiting list'
                                        : 'Leave waiting list',
                                  ),
                                  onTap: () => Navigator.pop(context, 'remove'),
                                ),
                              ListTile(
                                leading: const Icon(Icons.close),
                                title: const Text('Cancel'),
                                onTap: () => Navigator.pop(context, 'cancel'),
                              ),
                            ],
                          ),
                        );
                      },
                    );

                    if (!mounted || action == null || action == 'cancel') return;

                    if (action == 'arrived') {
                      await _toggleWaitingArrived(index);
                      return;
                    }

                    if (action == 'move') {
                      final targetSeatIndex = await _showPickOpenSeatDialog();
                      if (!mounted) return;
                      if (targetSeatIndex == null) return;

                      await _moveWaitingToSeat(index, targetSeatIndex);
                      return;
                    }

                    if (action == 'remove') {
                      await _removeFromWaitingListAt(index);
                      return;
                    }
                  },
                );
              }),
            )
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(TableData table) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    final isInWaitingList = table.waitingList.any((entry) {
      final entryUid = (entry['uid'] ?? '').toString().trim();
      return entryUid.isNotEmpty && entryUid == uid;
    });

    final isAlreadySeated = table.seats.any((seat) {
      final seatUid = (seat.playerUid ?? '').trim();
      return seatUid.isNotEmpty && seatUid == uid;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (!isInWaitingList)
            FilledButton.icon(
              onPressed: isAlreadySeated ? null : _addToWaitingList,
              icon: const Icon(Icons.playlist_add),
              label: Text(
                isAlreadySeated
                    ? 'Already seated'
                    : 'Add myself to waiting list',
              ),
            ),

          if (isInWaitingList)
            OutlinedButton.icon(
              onPressed: () async {
                final index = table.waitingList.indexWhere((entry) {
                  final entryUid = (entry['uid'] ?? '').toString().trim();
                  return entryUid.isNotEmpty && entryUid == uid;
                });

                if (index >= 0) {
                  await _removeFromWaitingListAt(index);
                }
              },
              icon: const Icon(Icons.playlist_remove),
              label: const Text('Leave Waiting'),
            ),

          if (canManageThisTable)
            FilledButton.icon(
              onPressed: _showAddPlayerToWaitingListSheet,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Player'),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddPlayerToWaitingListSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Select player'),
                onTap: () => Navigator.pop(context, 'select_player'),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Add guest'),
                onTap: () => Navigator.pop(context, 'add_guest'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'select_player') {
      await _addSelectedPlayerToWaitingList();
      return;
    }

    if (action == 'add_guest') {
      await _hostAddToWaitingList();
      return;
    }
  }

  Future<void> _addSelectedPlayerToWaitingList() async {
    final selectedPlayer = await _showSelectPlayerDialog();
    if (!mounted) return;
    if (selectedPlayer == null) return;

    final selectedUid = (selectedPlayer['uid'] ?? '').toString().trim();

    final selectedName =
        (selectedPlayer['displayName'] ??
                selectedPlayer['displayName'] ??
                '')
            .toString()
            .trim();

    final selectedShortName =
        (selectedPlayer['shortName'] ??
                selectedPlayer['displayName'] ??
                selectedName)
            .toString()
            .trim();
  
    final selectedPlayerId =
        (selectedPlayer['playerId'] ?? '').toString().trim();
  
    if (selectedName.isEmpty) {
      _showSnack('Invalid player');
      return;
    }

    try {
      await _runTableTransaction<void>((tx, snap, data) async {
        final seats = normalizeSeatMaps(data['seats']);
        final waitingList = List<dynamic>.from(data['waitingList'] ?? [])
            .map((e) => normalizeWaitingEntry(e))
            .toList();

        final alreadySeated = seats.any((seat) {
          final seatUid = (seat['playerUid'] ?? '').toString().trim();
          final seatPlayerId = (seat['playerId'] ?? '').toString().trim();
          final seatName = (seat['playerName'] ?? '').toString().trim();

          if (selectedUid.isNotEmpty && seatUid == selectedUid) return true;
          if (selectedPlayerId.isNotEmpty && seatPlayerId == selectedPlayerId) {
            return true;
          }
          return selectedUid.isEmpty &&
              selectedPlayerId.isEmpty &&
              seatName.toLowerCase() == selectedName.toLowerCase();
        });

        if (alreadySeated) {
          _txFail('This player is already seated');
        }

        final alreadyWaiting = waitingList.any((entry) {
          final uid = (entry['uid'] ?? '').toString().trim();
          final playerId = (entry['playerId'] ?? '').toString().trim();
          final name = (entry['name'] ?? '').toString().trim();

          if (selectedUid.isNotEmpty && uid == selectedUid) return true;
          if (selectedPlayerId.isNotEmpty && playerId == selectedPlayerId) {
            return true;
          }
          return selectedUid.isEmpty &&
              selectedPlayerId.isEmpty &&
              name.toLowerCase() == selectedName.toLowerCase();
        });

        if (alreadyWaiting) {
          _txFail('This player is already in waiting list');
        }

        waitingList.add({
          'uid': selectedUid,
          'name': selectedName,
          'shortName':
              selectedShortName.isNotEmpty ? selectedShortName : selectedName,
          'playerId': selectedPlayerId,
          'arrived': false,
        });

        tx.update(tableDocRef, {
          'waitingList': waitingList,
          ..._buildMetaUpdate(),
        });
      });

      if (!mounted) return;
      _showSnack('Player added to waiting list');

      if (selectedUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(selectedUid)
            .set({
          'hostPickCount': FieldValue.increment(1),
          'lastHostPickedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(_cleanError(e));
    }
  }

  Widget _buildDealerSeatWidget(
    TableData table, {
    bool isMobile = false,
  }) {
    final hasDealer =
        table.dealerName != null && table.dealerName!.trim().isNotEmpty;

    final dealerText =
        hasDealer ? 'Dealer: ${table.dealerName!.trim()}' : 'Dealer: ???';

  final double cardWidth = isMobile ? 130 : 132;
  final double horizontalPadding = isMobile ? 14 : 12;
  final double verticalPadding = isMobile ? 14 : 14;
  final double avatarRadius = isMobile ? 24 : 20;
  final double avatarFontSize = isMobile ? 22 : 20;
  final double titleFontSize = isMobile ? 13 : 12.5;
  final double subFontSize = isMobile ? 11 : 11.5;
  final double gap1 = isMobile ? 8 : 8;
  final double gap2 = isMobile ? 6 : 6;
  
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: canManageThisTable ? _setDealerName : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: cardWidth,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5CC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE67E22),
            width: 2.6,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: const Color(0xFFE67E22),
              child: Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: avatarFontSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(height: gap1),
            Text(
              dealerText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF7A3E00),
              ),
            ),
            SizedBox(height: gap2),
            Text(
              canManageThisTable
                  ? (hasDealer ? 'Change Dealer Name' : 'Set Dealer')
                  : 'Dealer Seat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subFontSize,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSeatAvatar({
    required bool isOpen,
    required bool isMine,
    required SeatReservation seat,
  }) {
    final isReserved =
        (seat.playerName?.trim().isEmpty ?? true) &&
        (
          (seat.reservedForName?.trim().isNotEmpty ?? false) ||
          (seat.reservedForUid?.trim().isNotEmpty ?? false) ||
          (seat.reservedForPlayerId?.trim().isNotEmpty ?? false)
        );

    if (isReserved) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFFFF3E0),
        child: Icon(
          Icons.bookmark,
          size: 18,
          color: Color(0xFFB45309),
        ),
      );
    }

    if (isOpen) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFE3F4E8),
        child: Icon(
          Icons.event_seat_outlined,
          size: 18,
          color: Color(0xFF2E9E5B),
        ),
      );
    }

    final displayName =
        (seat.playerShortName?.trim().isNotEmpty ?? false)
            ? seat.playerShortName!.trim()
            : (seat.playerName?.trim() ?? '');

    final avatarType =
        (seat.playerAvatarType ?? 'photo').trim().isEmpty
            ? 'photo'
            : seat.playerAvatarType!.trim();

    final avatarIcon =
        (seat.playerAvatarIcon ?? 'person').trim().isEmpty
            ? 'person'
            : seat.playerAvatarIcon!.trim();

    final avatarBgColor =
        seat.playerAvatarBgColor ?? 0xFF2563EB;

    return buildAppAvatar(
      radius: 18,
      avatar: AvatarSnapshot(
        avatarType: avatarType,
        avatarIcon: avatarIcon,
        avatarBgColor: avatarBgColor,
        photoUrl: avatarType == 'virtual' ? null : seat.playerPhotoUrl,
      ),
      displayName: displayName,
      iconSize: 18,
      textSize: 14,
    );
  }


  String _extractFirstName(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    return text.split(RegExp(r'\s+')).first.trim().toLowerCase();
  }
  
  String _normalizeText(String value) => value.trim().toLowerCase();
  
  String _entryIdentityKey({
    required String uid,
    required String playerId,
    required String name,
    required String shortName,
  }) {
    final cleanUid = uid.trim();
    if (cleanUid.isNotEmpty) return 'uid:$cleanUid';
  
    final cleanPlayerId = playerId.trim().toLowerCase();
    if (cleanPlayerId.isNotEmpty) return 'pid:$cleanPlayerId';
  
    final cleanShortName = shortName.trim().toLowerCase();
    if (cleanShortName.isNotEmpty) return 'guest:$cleanShortName';
  
    return 'guest:${name.trim().toLowerCase()}';
  }
  
  String _seatIdentityKey(Map<String, dynamic> seat) {
    final uid = (seat['playerUid'] ?? '').toString().trim();
    final playerId = (seat['playerId'] ?? '').toString().trim();
    final name = (seat['playerName'] ?? '').toString().trim();
    final shortName = (seat['playerShortName'] ?? '').toString().trim();
  
    return _entryIdentityKey(
      uid: uid,
      playerId: playerId,
      name: name,
      shortName: shortName,
    );
  }
  
  String _waitingIdentityKey(Map<String, dynamic> entry) {
    final uid = (entry['uid'] ?? '').toString().trim();
    final playerId = (entry['playerId'] ?? '').toString().trim();
    final name = (entry['name'] ?? '').toString().trim();
    final shortName = (entry['shortName'] ?? '').toString().trim();
  
    return _entryIdentityKey(
      uid: uid,
      playerId: playerId,
      name: name,
      shortName: shortName,
    );
  }

  String _buildDuplicateSafeName({
    required String fullName,
    required String shortName,
    required String lastName,
    required bool isMine,
  }) {
    final cleanFull = fullName.trim();
    final cleanShort = shortName.trim();
    final cleanLast = lastName.trim();
  
    if (cleanFull.isEmpty) return '';
  
    // 有 shortName 且不一樣 → 用 shortName (Joe T)
    if (cleanShort.isNotEmpty &&
        cleanShort.toLowerCase() != cleanFull.toLowerCase()) {
      return cleanShort;
    }
  
    // fallback：用 last initial
    if (cleanLast.isNotEmpty) {
      final first = cleanFull.split(RegExp(r'\s+')).first.trim();
      return '$first ${cleanLast[0].toUpperCase()}';
    }
  
    // 如果是自己 → 用 session shortName
    if (isMine) {
      final mineShort = widget.session.shortName.trim();
      if (mineShort.isNotEmpty &&
          mineShort.toLowerCase() != cleanFull.toLowerCase()) {
        return mineShort;
      }
    }
  
    return cleanFull;
  }

  String _buildWaitingDisplayName(TableData table, Map<String, dynamic> entry) {
    final fullName = (entry['name'] ?? '').toString().trim();
    final shortName = (entry['shortName'] ?? '').toString().trim();
    final uid = (entry['uid'] ?? '').toString().trim();
    final playerId = (entry['playerId'] ?? '').toString().trim();
  
    if (fullName.isEmpty && shortName.isEmpty) return '';
  
    final targetFirst =
        _extractFirstName(shortName.isNotEmpty ? shortName : fullName);
  
    bool duplicateFound = false;
  
    for (final seat in table.seats) {
      final seatUid = (seat.playerUid ?? '').trim();
      final seatPlayerId = (seat.playerId ?? '').trim();
      final seatName = (seat.playerName ?? '').trim();
      final seatShortName = (seat.playerShortName ?? '').trim();
  
      if (seatName.isEmpty && seatShortName.isEmpty) continue;
  
      final isSamePerson =
          (uid.isNotEmpty && seatUid == uid) ||
          (playerId.isNotEmpty && seatPlayerId == playerId);
  
      if (isSamePerson) continue;
  
      final compareBase = seatShortName.isNotEmpty ? seatShortName : seatName;
  
      if (_extractFirstName(compareBase) == targetFirst) {
        duplicateFound = true;
        break;
      }
    }
  
    if (duplicateFound) {
      if (shortName.isNotEmpty) return shortName;
      return fullName;
    }
  
    return fullName;
  }

  String _buildWaitingTypeLabel(Map<String, dynamic> entry) {
    final uid = (entry['uid'] ?? '').toString().trim();
    final playerId = (entry['playerId'] ?? '').toString().trim();
  
    if (uid.isNotEmpty) return 'Player';
    if (playerId.isNotEmpty) return 'Known Player';
    return 'Guest';
  }

  bool _hasDuplicateFirstName(TableData table, String targetName) {
    final targetFirst = _extractFirstName(targetName);
    if (targetFirst.isEmpty) return false;
  
    int count = 0;
  
    for (final s in table.seats) {
      final playerName = (s.playerName ?? '').trim();
      final playerShortName = (s.playerShortName ?? '').trim();
      final reservedName = (s.reservedForName ?? '').trim();
      final reservedShortName = (s.reservedForShortName ?? '').trim();
  
      final occupiedBase =
          playerShortName.isNotEmpty ? playerShortName : playerName;
      final reservedBase =
          reservedShortName.isNotEmpty ? reservedShortName : reservedName;
  
      if (occupiedBase.isNotEmpty &&
          _extractFirstName(occupiedBase) == targetFirst) {
        count++;
      }
  
      if (reservedBase.isNotEmpty &&
          _extractFirstName(reservedBase) == targetFirst) {
        count++;
      }
    }
  
    for (final entry in table.waitingList) {
      final waitingName = (entry['name'] ?? '').toString().trim();
      final waitingShortName = (entry['shortName'] ?? '').toString().trim();
  
      final waitingBase =
          waitingShortName.isNotEmpty ? waitingShortName : waitingName;
  
      if (waitingBase.isNotEmpty &&
          _extractFirstName(waitingBase) == targetFirst) {
        count++;
      }
    }
  
    return count >= 2;
  }

  String _resolveSeatDisplayName({
    required TableData table,
    required String fullName,
    required String shortName,
    required String lastName,
    required bool isMine,
  }) {
    final cleanFull = fullName.trim();
    final cleanShort = shortName.trim();
    final cleanLast = lastName.trim();
  
    if (cleanFull.isEmpty && cleanShort.isEmpty) return '';
  
    final baseName = cleanFull.isNotEmpty ? cleanFull : cleanShort;
    final hasDuplicate = _hasDuplicateFirstName(table, baseName);
  
    if (!hasDuplicate) {
      return cleanFull.isNotEmpty ? cleanFull : cleanShort;
    }
  
    if (cleanShort.isNotEmpty &&
        cleanShort.toLowerCase() != cleanFull.toLowerCase()) {
      return cleanShort;
    }
  
    if (cleanLast.isNotEmpty) {
      final first = _extractFirstName(cleanFull);
      if (first.isNotEmpty) {
        return '$first ${cleanLast[0].toUpperCase()}';
      }
    }
  
    if (isMine) {
      final mineShort = widget.session.shortName.trim();
      if (mineShort.isNotEmpty &&
          mineShort.toLowerCase() != cleanFull.toLowerCase()) {
        return mineShort;
      }
    }
  
    return cleanFull.isNotEmpty ? cleanFull : cleanShort;
  }



  String buildSeatLabel({
    required SeatReservation seat,
    required String displayName,
    required int seatIndex,
  }) {
    if (displayName.trim().isEmpty) {
      return 'Open Seat';
    }

    return displayName;
  }

  List<Offset> _mobileSeatCentersFor(Rect tableRect, int seatCount) {
    final centerX = tableRect.left + tableRect.width / 2;

    final leftFarX = tableRect.left - 78;
    final leftMidX = tableRect.left - 18;
    final leftNearX = tableRect.left + 34;

    final rightNearX = tableRect.right - 34;
    final rightMidX = tableRect.right + 18;
    final rightFarX = tableRect.right + 78;

    final topCenterY = tableRect.top + 10;
    final topSideY = tableRect.top + 56;
    final midSideY = tableRect.top + 122;
    final lowerSideY = tableRect.bottom - 4;
    final bottomY = tableRect.bottom + 56;
    final bottomWideY = tableRect.bottom + 74;

    final layout9 = <Offset>[
      Offset(rightNearX, topSideY),
      Offset(rightFarX, midSideY),
      Offset(rightFarX, lowerSideY),
      Offset(rightNearX, bottomY),
      Offset(centerX, bottomWideY),
      Offset(leftNearX, bottomY),
      Offset(leftFarX, lowerSideY),
      Offset(leftFarX, midSideY),
      Offset(leftNearX, topSideY),
    ];

    final layout10 = <Offset>[
      Offset(centerX + 56, topCenterY),
      Offset(rightFarX, topSideY + 18),
      Offset(rightFarX, lowerSideY),
      Offset(rightNearX, bottomY),
      Offset(centerX + 48, bottomWideY),
      Offset(centerX - 48, bottomWideY),
      Offset(leftNearX, bottomY),
      Offset(leftFarX, lowerSideY),
      Offset(leftFarX, topSideY + 18),
      Offset(centerX - 56, topCenterY),
    ];

    final layout11 = <Offset>[
      Offset(centerX, topCenterY - 8),
      Offset(centerX + 70, topCenterY + 8),
      Offset(rightFarX, topSideY + 24),
      Offset(rightFarX, lowerSideY),
      Offset(rightNearX, bottomY),
      Offset(centerX + 58, bottomWideY),
      Offset(centerX - 58, bottomWideY),
      Offset(leftNearX, bottomY),
      Offset(leftFarX, lowerSideY),
      Offset(leftFarX, topSideY + 24),
      Offset(centerX - 70, topCenterY + 8),
    ];

    if (seatCount == 10) {
      return layout10;
    }

    if (seatCount >= 11) {
      return layout11;
    }

    return layout9;
  }

    Offset _moveSeatCloserToTable({
    required Offset seatCenter,
    required Rect tableRect,
    required double amount,
  }) {
    final tableCenter = Offset(
      tableRect.left + tableRect.width / 2,
      tableRect.top + tableRect.height / 2,
    );

    final dx = tableCenter.dx - seatCenter.dx;
    final dy = tableCenter.dy - seatCenter.dy;
    final distance = math.sqrt((dx * dx) + (dy * dy));

    if (distance == 0) return seatCenter;

    final unitX = dx / distance;
    final unitY = dy / distance;

    return Offset(
      seatCenter.dx + (unitX * amount),
      seatCenter.dy + (unitY * amount),
    );
  }

  Widget _buildTableArea(TableData table) {
    final seatCount = table.playerSeatCount;
    final seats = table.seats;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final areaWidth = constraints.maxWidth;
        final boardWidth = isMobile ? 820.0 : areaWidth;
        final boardHeight = isMobile ? 660.0 : math.max(520.0, areaWidth * 0.62);

        final tableWidth = isMobile ? 620.0 : boardWidth * 0.72;
        final tableHeight = isMobile ? 320.0 : boardHeight * 0.52;

        final tableLeft = (boardWidth - tableWidth) / 2;
        final tableTop = isMobile ? 200.0 : 150.0;

        final tableRect = Rect.fromLTWH(
          tableLeft,
          tableTop,
          tableWidth,
          tableHeight,
        );

        final centerX = tableRect.left + tableRect.width / 2;

        final rawSeatCenters =
            _buildPokerStarsDesktopSeatCenters(tableRect, seatCount);

        final seatCenters = List<Offset>.generate(
          rawSeatCenters.length,
          (index) {
            var center = rawSeatCenters[index];

            if (isMobile && seatCount == 9) {
              if (index == 1) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 18,
                );
              } else if (index == 2) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 28,
                );
              } else if (index == 4) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 38,
                );

              } else if (index == 6) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 28,
                );
              } else if (index == 7) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 18,
                );
              }
            } else if (isMobile && seatCount == 10) {
              if (index == 1) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 18,
                );
              } else if (index == 2) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 32,
                );
              } else if (index == 4) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 38,
                );
              } else if (index == 5) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 38,
                );
              } else if (index == 7) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 32,
                );
              } else if (index == 8) {
                center = _moveSeatCloserToTable(
                  seatCenter: center,
                  tableRect: tableRect,
                  amount: 18,
                );
              }
            }

            return center;
          },
        );  

        final dealerCardWidth = isMobile ? 96.0 : 132.0;
        final dealerTop = isMobile ? (tableTop - 120.0) : (tableTop - 130.0);

        final board = SizedBox(
          width: boardWidth,
          height: boardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: tableLeft,
                top: tableTop,
                child: Container(
                  width: tableWidth,
                  height: tableHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          table.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          table.stakes.isNotEmpty ? table.stakes : 'Cash Game',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: centerX - (dealerCardWidth / 2),
                top: dealerTop,
                child: _buildDealerSeatWidget(
                  table,
                  isMobile: isMobile,
                ),
              ),

              for (int i = 0; i < seatCount; i++)
                Builder(
                  builder: (context) {
                    final center = i < seatCenters.length
                        ? seatCenters[i]
                        : seatCenters.last;

                    return Positioned(
                      left: center.dx - 52,
                      top: center.dy - 42,
                      child: Transform.scale(
                        scale: isMobile
                            ? (seatCount == 10 ? 1.00 : 1.04)
                            : 1.0,
                        alignment: Alignment.center,
                        child: _buildSeatWidget(
                          table: table,
                          seatIndex: i,
                          seat: i < seats.length ? seats[i] : SeatReservation(),
                          isDealerSeat: false,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );

        if (isMobile) {
          return SizedBox(
            width: constraints.maxWidth,
            height: 500,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: board,
            ),
          );
        }

        return SizedBox(
          width: areaWidth,
          height: boardHeight,
          child: board,
        );
      },
    );
  }

    Widget _buildSeatWidget({
    required TableData table,
    required int seatIndex,
    required SeatReservation seat,
    required bool isDealerSeat,
  }) {
    final myName = widget.session.name.trim();

    final playerName = seat.playerName?.trim() ?? '';
    final playerShortName = seat.playerShortName?.trim() ?? '';
    final playerLastName = seat.playerLastName?.trim() ?? '';

    final reservedName = seat.reservedForName?.trim() ?? '';
    final reservedShortName = seat.reservedForShortName?.trim() ?? '';

    final isReserved =
        playerName.isEmpty &&
        (reservedName.isNotEmpty ||
            reservedShortName.isNotEmpty ||
            (seat.reservedForUid?.trim().isNotEmpty ?? false) ||
            (seat.reservedForPlayerId?.trim().isNotEmpty ?? false));

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final isMine = playerName.isNotEmpty &&
        (
          ((seat.playerUid ?? '').trim().isNotEmpty &&
              (seat.playerUid ?? '').trim() == currentUid) ||
          ((seat.playerUid ?? '').trim().isEmpty && playerName == myName)
        );

    String displayName = '';

    if (playerName.isNotEmpty) {
      displayName = _resolveSeatDisplayName(
        table: table,
        fullName: playerName,
        shortName: playerShortName,
        lastName: playerLastName,
        isMine: isMine,
      );
    } else if (isReserved) {
      final baseReservedName =
          reservedName.isNotEmpty ? reservedName : reservedShortName;

      final hasDuplicate = _hasDuplicateFirstName(table, baseReservedName);

      if (hasDuplicate) {
        displayName = reservedShortName.isNotEmpty
            ? reservedShortName
            : reservedName;
      } else {
        displayName = reservedName.isNotEmpty ? reservedName : reservedShortName;
      }
    }

    final isOpen = displayName.isEmpty;
    final isSelectedForMove = movingSeatIndex == seatIndex;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _onSeatTap(seatIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: _seatFillColor(
            isOpen: isOpen,
            isMine: isMine,
            isDealerSeat: isDealerSeat,
            isSelectedForMove: isSelectedForMove,
            seat: seat,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _seatBorderColor(
              isOpen: isOpen,
              isMine: isMine,
              isDealerSeat: isDealerSeat,
              isSelectedForMove: isSelectedForMove,
              seat: seat,
            ),
            width: isMine || isDealerSeat || isSelectedForMove ? 2.4 : 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSeatAvatar(
              isOpen: isOpen,
              isMine: isMine,
              seat: seat,
            ),
            const SizedBox(height: 8),
            Text(
              isOpen ? 'Open Seat' : displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Seat ${seatIndex + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            if (!isOpen) ...[
              const SizedBox(height: 4),
              Text(
                isMine
                    ? ((seat.arrived == true) ? 'Arrived' : 'Unarrived')
                    : ((isReserved
                            ? (seat.reservedArrived == true)
                            : (seat.arrived == true))
                        ? 'Arrived'
                        : 'Unarrived'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isMine
                      ? const Color(0xFF2563EB)
                      : Colors.black,
                ),
              ),
            ],
            if (isReserved) ...[
              const SizedBox(height: 4),
              const Text(
                'Reserved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Offset> _buildEvenSeatCenters({
    required Rect tableRect,
    required int seatCount,
    required double startAngle,
    required double endAngle,
    required double radiusXFactor,
    required double radiusYFactor,
    double centerYOffset = 0,
  }) {
    final centerX = tableRect.left + tableRect.width / 2;
    final centerY = tableRect.top + tableRect.height / 2 + centerYOffset;

    final radiusX = tableRect.width * radiusXFactor;
    final radiusY = tableRect.height * radiusYFactor;

    if (seatCount <= 0) return [];

    if (seatCount == 1) {
      final angle = (startAngle + endAngle) / 2;
      return [
        Offset(
          centerX + radiusX * math.cos(angle),
          centerY + radiusY * math.sin(angle),
        ),
      ];
    }

    final step = (endAngle - startAngle) / (seatCount - 1);

    return List.generate(seatCount, (index) {
      final angle = startAngle + (step * index);

      return Offset(
        centerX + radiusX * math.cos(angle),
        centerY + radiusY * math.sin(angle),
      );
    });
  }

  List<Offset> _buildPokerStarsDesktopSeatCenters(
    Rect tableRect,
    int seatCount,
  ) {
    if (seatCount == 10) {
      return _buildEvenSeatCenters(
        tableRect: tableRect,
        seatCount: seatCount,
        startAngle: -1.02,
        endAngle: 4.16,
        radiusXFactor: 0.68,
        radiusYFactor: 0.80,
        centerYOffset: 8,
      );
    }

    return _buildEvenSeatCenters(
      tableRect: tableRect,
      seatCount: seatCount,
      startAngle: -0.98,
      endAngle: 4.12,
      radiusXFactor: 0.67,
      radiusYFactor: 0.79,
      centerYOffset: 8,
    );
  }

  Future<void> _endGame() async {
    if (!canManageThisTable) {
      _showSnack('Only the table creator can end this game');
      return;
    }
  
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game'),
        content: const Text(
          'This will delete this table and return to Table List.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Game'),
          ),
        ],
      ),
    );
  
    if (confirmed != true) return;
  
    try {
      await tableDocRef.delete();
  
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack(_cleanError(e));
    }
  }

  Future<void> _openFriendsHub() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsHubPage(
          session: widget.session,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDirectChatFromFriendship(
    Map<String, dynamic> friendshipData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userA = Map<String, dynamic>.from(friendshipData['userA'] ?? {});
    final userB = Map<String, dynamic>.from(friendshipData['userB'] ?? {});
    final nicknames = Map<String, dynamic>.from(friendshipData['nicknames'] ?? {});

    final otherUser =
        (userA['uid'] ?? '').toString() == currentUser.uid ? userB : userA;

    final myNickname = (nicknames[currentUser.uid] ?? '').toString().trim();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          chatId: (friendshipData['chatId'] ?? '').toString(),
          otherUid: (otherUser['uid'] ?? '').toString(),
          otherDisplayName: (otherUser['displayName'] ?? 'Chat').toString(),
          otherPhotoUrl: (otherUser['photoUrl'] ?? '').toString(),
          otherNickname: myNickname,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildFriendsPanelCard() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('friendships')
              .where('memberUids', arrayContains: currentUid)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = [...(snapshot.data?.docs ?? [])]
              ..sort((a, b) {
                final aData = a.data();
                final bData = b.data();

                final aTime = aData['updatedAt'];
                final bTime = bData['updatedAt'];

                final aMillis =
                    aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
                final bMillis =
                    bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

                return bMillis.compareTo(aMillis);
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Friends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openFriendsHub,
                      child: const Text('Open All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (docs.isEmpty)
                  const Text(
                    'No friends yet',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Column(
                    children: docs.take(6).map((doc) {
                      final data = doc.data();
                      final userA = Map<String, dynamic>.from(data['userA'] ?? {});
                      final userB = Map<String, dynamic>.from(data['userB'] ?? {});
                      final otherUser =
                          (userA['uid'] ?? '').toString() == currentUid
                              ? userB
                              : userA;

                      final avatarData = resolveAvatarFieldsFromMap(otherUser);

                      final photoUrl = avatarData['photoUrl'] as String;
                      final avatarType = avatarData['avatarType'] as String;
                      final avatarIcon = avatarData['avatarIcon'] as String;
                      final avatarBgColor = avatarData['avatarBgColor'] as int;                         

                      final chatId = (data['chatId'] ?? '').toString();

                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('direct_chats')
                            .doc(chatId)
                            .snapshots(),
                        builder: (context, chatSnapshot) {
                          final chatData = chatSnapshot.data?.data() ?? {};
                          final unreadCounts =
                              Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});
                          final unreadRaw = unreadCounts[currentUid] ?? 0;
                          final unreadCount = unreadRaw is int
                              ? unreadRaw
                              : int.tryParse(unreadRaw.toString()) ?? 0;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,

                            leading: buildAppAvatar(
                              radius: 20,
                              avatar: AvatarSnapshot(
                                avatarType: avatarType,
                                avatarIcon: avatarIcon,
                                avatarBgColor: avatarBgColor,
                                photoUrl: photoUrl,
                              ),
                              displayName: (otherUser['displayName'] ?? 'Unknown').toString(),
                              iconSize: 18,
                              textSize: 14,
                            ),

                            title: Text(
                              (otherUser['displayName'] ?? 'Unknown').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              unreadCount > 0
                                  ? '$unreadCount unread'
                                  : 'No unread messages',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unreadCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      unreadCount > 99
                                          ? '99+'
                                          : unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                FilledButton(
                                  onPressed: () =>
                                      _openDirectChatFromFriendship(data),
                                  child: const Text('Chat'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: tableDocRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text(
                'Table Details',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text(
                'Table Details',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text(
                'Table Details',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            body: const Center(
              child: Text('Table not found'),
            ),
          );
        }

        final table = TableData.fromMap(data);
        _handleWaitingListEvent(data);
        final takenCount = table.seats.where((seat) => !seat.isOpen).length;
        final openCount = table.playerSeatCount - takenCount;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              table.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),                               

            actions: [
              FriendsNotificationButton(
                onTap: _openFriendsHub,
              ),
              if (canManageThisTable)
                TextButton.icon(
                  onPressed: _endGame,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Game'),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTableHeaderCard(table, openCount, takenCount),
                const SizedBox(height: 14),

                if (canManageThisTable)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: DropdownButton<int>(
                        value: table.playerSeatCount,
                        underline: const SizedBox(),
                        borderRadius: BorderRadius.circular(14),
                        items: const [
                          DropdownMenuItem(value: 9, child: Text('9 Players')),
                          DropdownMenuItem(value: 10, child: Text('10 Players')),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            await _changeSeatCount(value);
                          }
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isEffectiveHost
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFEFF7F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEffectiveHost
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFD5E7D8),
                    ),
                  ),
                  child: Text(
                    isEffectiveHost
                        ? 'Host: tap any seat to manage reservations, remove players, or move players.'
                        : 'Player: tap an open seat to join, tap your own seat to cancel.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isEffectiveHost
                          ? Colors.blue.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                _buildTableArea(table),
                const SizedBox(height: 18),

                _buildWaitingListCard(table),
                const SizedBox(height: 14),

                _buildQuickActionsCard(table),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SeatTableBoard extends StatelessWidget {
  final int? movingSeatIndex;
  final String tableName;
  final String currentUserName;
  final List<SeatReservation> seats;
  final ValueChanged<int> onSeatTap;
  final String? dealerName;

  const SeatTableBoard({
    super.key,
    required this.movingSeatIndex,
    required this.tableName,
    required this.currentUserName,
    required this.seats,
    required this.onSeatTap,
    this.dealerName,
  });

  bool _isMineSeat(SeatReservation seat) {
    final seatName = (seat.playerName ?? '').trim().toLowerCase();
    final seatShortName = (seat.playerShortName ?? '').trim().toLowerCase();
    final myName = currentUserName.trim().toLowerCase();

    return seatName == myName || seatShortName == myName;
  }

  List<Offset> _buildSeatOffsets(int seatCount) {
    if (seatCount == 9) {
      return const [
        Offset(0.17, 0.26),
        Offset(0.50, 0.16),
        Offset(0.83, 0.26),
        Offset(0.91, 0.48),
        Offset(0.78, 0.76),
        Offset(0.50, 0.86),
        Offset(0.22, 0.76),
        Offset(0.09, 0.48),
        Offset(0.15, 0.61),
      ];
    }

    if (seatCount == 10) {
      return const [
        Offset(0.15, 0.25),
        Offset(0.35, 0.16),
        Offset(0.65, 0.16),
        Offset(0.85, 0.25),
        Offset(0.92, 0.46),
        Offset(0.84, 0.73),
        Offset(0.65, 0.86),
        Offset(0.35, 0.86),
        Offset(0.16, 0.73),
        Offset(0.08, 0.46),
      ];
    }

    return const [
      Offset(0.15, 0.25),
      Offset(0.33, 0.15),
      Offset(0.50, 0.12),
      Offset(0.67, 0.15),
      Offset(0.85, 0.25),
      Offset(0.93, 0.46),
      Offset(0.84, 0.73),
      Offset(0.67, 0.86),
      Offset(0.50, 0.90),
      Offset(0.33, 0.86),
      Offset(0.16, 0.73),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final count = seats.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w < 430 ? 560.0 : 650.0;
        final offsets = _buildSeatOffsets(count);

        const seatWidth = 108.0;
        const seatHeight = 96.0;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: w * 0.14,
                top: h * 0.31,
                child: Container(
                  width: w * 0.72,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF166534),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        tableName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (w - seatWidth) / 2,
                top: h * 0.11,
                child: DealerSeatWidget(
                  dealerName: dealerName,
                  canEdit: false,
                  onTap: () {},
                ),
              ),
              for (int i = 0; i < count; i++)
                Positioned(
                  left: offsets[i].dx * w - (seatWidth / 2),
                  top: offsets[i].dy * h - (seatHeight / 2),
                  child: PlayerSeatWidget(
                    seatNumber: i + 1,
                    seat: seats[i],
                    isMine: _isMineSeat(seats[i]),
                    isMoving: movingSeatIndex == i,
                    onTap: () => onSeatTap(i),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class DealerSeatWidget extends StatelessWidget {
  final String? dealerName;
  final bool canEdit;
  final VoidCallback onTap;

  const DealerSeatWidget({
    super.key,
    required this.dealerName,
    required this.canEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        dealerName == null || dealerName!.trim().isEmpty
            ? 'Dealer'
            : dealerName!.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFB923C),
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF28C28),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7C2D12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerSeatWidget extends StatelessWidget {
  final int seatNumber;
  final SeatReservation seat;
  final bool isMine;
  final bool isMoving;
  final VoidCallback onTap;

  const PlayerSeatWidget({
    super.key,
    required this.seatNumber,
    required this.seat,
    required this.isMine,
    required this.isMoving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReserved =
        (seat.playerName?.trim().isEmpty ?? true) &&
        (
          (seat.reservedForName?.trim().isNotEmpty ?? false) ||
          (seat.reservedForUid?.trim().isNotEmpty ?? false) ||
          (seat.reservedForPlayerId?.trim().isNotEmpty ?? false)
        );

    final isOccupied =
        (seat.playerName?.trim().isNotEmpty ?? false) ||
        (seat.playerUid?.trim().isNotEmpty ?? false);

    final isOpen = !isReserved && !isOccupied;

    final displayName = isReserved
        ? ((seat.reservedForShortName?.trim().isNotEmpty ?? false)
            ? seat.reservedForShortName!.trim()
            : (seat.reservedForName?.trim() ?? 'Reserved'))
        : ((seat.playerShortName?.trim().isNotEmpty ?? false)
            ? seat.playerShortName!.trim()
            : (seat.playerName?.trim() ?? ''));

    final avatarType = (seat.playerAvatarType ?? 'photo').trim().isEmpty
        ? 'photo'
        : seat.playerAvatarType!.trim();

    final avatarIcon = (seat.playerAvatarIcon ?? 'person').trim().isEmpty
        ? 'person'
        : seat.playerAvatarIcon!.trim();

    final avatarBgColor = seat.playerAvatarBgColor ?? 0xFF2563EB;

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid.trim() ?? '';
    final currentDisplayName = currentUser?.displayName?.trim().toLowerCase() ?? '';

    final seatUid = (seat.playerUid ?? '').trim();
    final seatName = (seat.playerName ?? '').trim().toLowerCase();

    final isCurrentUsersSeat =
        !isReserved &&
        (
          isMine ||
          (currentUid.isNotEmpty && seatUid == currentUid) ||
          (currentDisplayName.isNotEmpty && seatName == currentDisplayName)
        );

    final Widget avatarWidget = buildAppAvatar(
      radius: 18,
      avatar: AvatarSnapshot(
        avatarType: isReserved ? 'photo' : avatarType,
        avatarIcon: isReserved ? 'person' : avatarIcon,
        avatarBgColor: isReserved ? 0xFF2563EB : avatarBgColor,
        photoUrl: isReserved
            ? null
            : (avatarType == 'virtual' ? null : seat.playerPhotoUrl),
      ),
      displayName: displayName,
      iconSize: 18,
      textSize: 14,
    );

    final isArrived = isReserved
        ? (seat.reservedArrived == true)
        : (seat.arrived == true);

    final Color bgColor;
    final Color borderColor;
    final Color statusColor;
    final Color nameColor;
    final String statusText;
    final String playerText;
    final IconData topIcon;

    if (isMoving) {
      bgColor = const Color(0xFFE5E7EB);
      borderColor = Colors.black;
      statusColor = Colors.black;
      nameColor = Colors.black;
      statusText = 'MOVING';
      playerText = displayName;
      topIcon = Icons.drive_file_move_outline;
    } else if (isOpen) {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFD1D5DB);
      statusColor = const Color(0xFF16A34A);
      nameColor = const Color(0xFF374151);
      statusText = 'OPEN';
      playerText = 'Seat $seatNumber';
      topIcon = Icons.event_seat;
    } else if (isMine) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFF2563EB);
      statusColor = const Color(0xFF2563EB);
      nameColor = const Color(0xFF1D4ED8);
      statusText = 'YOU';
      playerText = displayName;
      topIcon = Icons.person;
    } else if (isArrived) {
      bgColor = const Color(0xFFEDE9FE);
      borderColor = const Color.fromARGB(255, 230, 100, 241);
      statusColor = const Color.fromARGB(255, 230, 100, 241);
      nameColor = const Color(0xFF991B1B);
      statusText = 'ARRIVED';
      playerText = displayName;
      topIcon = isReserved ? Icons.bookmark : Icons.check_circle;
    } else {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color.fromARGB(255, 248, 58, 58);
      statusColor = const Color.fromARGB(255, 248, 58, 58);
      nameColor = const Color(0xFF9A3412);
      statusText = 'UNARRIVED';
      playerText = displayName;
      topIcon = isReserved ? Icons.bookmark : Icons.schedule;
    }

    final Widget seatTopWidget =
        (isOpen || isMoving || isReserved)
            ? Icon(
                topIcon,
                size: 20,
                color: statusColor,
              )
            : avatarWidget;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isMine ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            seatTopWidget,
            const SizedBox(height: 6),
            Text(
              playerText,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: nameColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ListChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ListChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class CashGameSessionItem {
  final String id;
  final String userUid;
  final String game;
  final String stakes;
  final String location;
  final double buyIn;
  final double cashOut;
  final double tips;
  final String note;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isOngoing;

  const CashGameSessionItem({
    required this.id,
    required this.userUid,
    required this.game,
    required this.stakes,
    required this.location,
    required this.buyIn,
    required this.cashOut,
    required this.tips,
    required this.note,
    required this.startedAt,
    required this.endedAt,
    required this.isOngoing,
  });

  double get profit => cashOut - buyIn - tips;

  double get hours {
    final end = endedAt ?? DateTime.now();
    final minutes = end.difference(startedAt).inMinutes;
    if (minutes <= 0) return 0;
    return minutes / 60.0;
  }

  String get gameLabel => '${stakes.trim()} ${game.trim()}'.trim();

  factory CashGameSessionItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return CashGameSessionItem(
      id: doc.id,
      userUid: (data['userUid'] ?? '').toString().trim(),
      game: (data['game'] ?? 'Texas Holdem').toString().trim(),
      stakes: (data['stakes'] ?? '').toString().trim(),
      location: (data['location'] ?? '').toString().trim(),
      buyIn: _toDouble(data['buyIn']),
      cashOut: _toDouble(data['cashOut']),
      tips: _toDouble(data['tips']),
      note: (data['note'] ?? '').toString(),
      startedAt: firestoreDateTime(data['startedAt']) ?? DateTime.now(),
      endedAt: firestoreDateTime(data['endedAt']),
      isOngoing: data['isOngoing'] == true,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

enum CashGameLocationType {
  homeGame,
  casino,
}

String _normalizeLocationForDisplay(String rawLocation) {
  final value = rawLocation.trim();

  if (value.isEmpty) {
    return '';
  }

  final lower = value.toLowerCase();

  if (lower.endsWith("'s game")) {
    final base = value.substring(0, value.length - "'s Game".length).trim();
    if (base.isEmpty) return '';
    return "$base's Game";
  }

  if (lower.endsWith("'s")) {
    final base = value.substring(0, value.length - 2).trim();
    if (base.isEmpty) return '';
    return "$base's Game";
  }

  if (lower.endsWith("' house")) {
    final base = value.substring(0, value.length - "' house".length).trim();
    if (base.isEmpty) return '';
    return "$base's Game";
  }

  if (lower.endsWith("'s house")) {
    final base = value.substring(0, value.length - "'s house".length).trim();
    if (base.isEmpty) return '';
    return "$base's Game";
  }

  if (lower.endsWith(" casino")) {
    final base = value.substring(0, value.length - " casino".length).trim();
    if (base.isEmpty) return '';
    return "$base Casino";
  }

  return value;
}

String _extractEditableLocationName(String rawLocation) {
  final normalized = _normalizeLocationForDisplay(rawLocation);
  final lower = normalized.toLowerCase();

  if (lower.endsWith("'s game")) {
    return normalized.substring(0, normalized.length - "'s Game".length).trim();
  }

  if (lower.endsWith(" casino")) {
    return normalized.substring(0, normalized.length - " Casino".length).trim();
  }

  return normalized;
}

CashGameLocationType _detectLocationType(String rawLocation) {
  final normalized = _normalizeLocationForDisplay(rawLocation);
  final lower = normalized.toLowerCase();

  if (lower.endsWith(' casino')) {
    return CashGameLocationType.casino;
  }

  return CashGameLocationType.homeGame;
}

String _moneyText(num value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs().toStringAsFixed(2);
  return '$sign\$$abs';
}

String _moneyShortText(num value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();

  if (abs == abs.roundToDouble()) {
    return '$sign\$${abs.toStringAsFixed(0)}';
  }

  return '$sign\$${abs.toStringAsFixed(2)}';
}

String _hourText(num value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}

String _dateText(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _dateTimeText(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _weekdayZh(DateTime dt) {
  const labels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return labels[dt.weekday - 1];
}

Color _profitColor(num value) {
  if (value > 0) return const Color(0xFF16A34A);
  if (value < 0) return const Color(0xFFDC2626);
  return Colors.black87;
}

class CashGameStatsPage extends StatelessWidget {
  final UserSession session;
  final bool hasPaidAccess;
  final String paymentUrl;

  const CashGameStatsPage({
    super.key,
    required this.session,
    required this.hasPaidAccess,
    required this.paymentUrl,
  });

  @override
  Widget build(BuildContext context) {
    return CashGameStatsHomePage(
      session: session,
      hasPaidAccess: hasPaidAccess,
      paymentUrl: paymentUrl,
    );
  }
}

class CashGameStatsLockedPage extends StatelessWidget {
  final String paymentUrl;

  const CashGameStatsLockedPage({
    super.key,
    required this.paymentUrl,
  });

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF16A34A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cash Game Stats',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.workspace_premium,
                        size: 64,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Unlock Cash Game Stats',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'You need to pay to see your hand statistics, monthly reports, location performance, and hourly profit and loss.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildBenefit('View total profit/loss, hourly profit/loss, average profit/loss per game'),
                    _buildBenefit('View location group profit'),
                    _buildBenefit('View game group profit'),
                    _buildBenefit('View weekly group profit'),
                    _buildBenefit('View monthly profit'),
                    _buildBenefit('Continuously track ongoing games'),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Link',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            paymentUrl,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: paymentUrl),
                              );

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment link copied'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Payment Link'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CashGameStatsHomePage extends StatefulWidget {
  final UserSession session;
  final bool hasPaidAccess;
  final String paymentUrl;

  const CashGameStatsHomePage({
    super.key,
    required this.session,
    required this.hasPaidAccess,
    required this.paymentUrl,
  });

  @override
  State<CashGameStatsHomePage> createState() => _CashGameStatsHomePageState();
}

class _CashGameStatsHomePageState extends State<CashGameStatsHomePage> {

  static const String _statsProPriceId =
      'price_1TMRxVCeafvLbyRizC2lvERT';

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _openEditor({
    CashGameSessionItem? item,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CashGameSessionEditorPage(
          item: item,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startStatsCheckout() async {
    if (isAppleIapPlatform) {
      try {
        await AppleIapService.buy(
          productId: kAppleStatsProProductId,
          type: ApplePurchaseType.stats,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stats Pro activated')),
        );

        setState(() {});
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }

      return;
    }

    try {
      final url = Uri.parse(widget.paymentUrl);

      final ok = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open payment page')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open payment page: $e')),
      );
    }
  }

  Future<void> _deleteSession(String docId) async {
    await FirebaseFirestore.instance
        .collection('cash_game_sessions')
        .doc(docId)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session deleted')),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, double>> _buildGroupedData(
    List<CashGameSessionItem> items,
    String Function(CashGameSessionItem item) groupKey,
  ) {
    final result = <String, Map<String, double>>{};

    for (final item in items.where((e) => !e.isOngoing && e.endedAt != null)) {
      final key = groupKey(item);

      result.putIfAbsent(key, () {
        return {
          'profit': 0,
          'hours': 0,
          'count': 0,
        };
      });

      result[key]!['profit'] = (result[key]!['profit'] ?? 0) + item.profit;
      result[key]!['hours'] = (result[key]!['hours'] ?? 0) + item.hours;
      result[key]!['count'] = (result[key]!['count'] ?? 0) + 1;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login again')),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cash Game Stats',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'All Games'),
              Tab(text: 'Location Profits'),
              Tab(text: 'Game Profits'),
              Tab(text: 'Weekly Profits'),
              Tab(text: 'Monthly Profits'),
            ],
          ),
        ),
        floatingActionButton: widget.hasPaidAccess
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'ongoing') {
                    _openEditor();
                  } else if (value == 'ended') {
                    _openEditor();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'ongoing',
                    child: Text('Add an ongoing game'),
                  ),
                  PopupMenuItem<String>(
                    value: 'ended',
                    child: Text('Add an already finished game'),
                  ),
                ],
                child: FloatingActionButton.extended(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add game',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
            : FloatingActionButton.extended(
                onPressed: _startStatsCheckout,
                backgroundColor: const Color(0xFFDBEAFE),
                foregroundColor: const Color(0xFF1D4ED8),
                icon: const Icon(Icons.workspace_premium),
                label: const Text(
                  'Upgrade to Stats Pro',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('cash_game_sessions')
              .where('userUid', isEqualTo: _currentUid)
              .orderBy('startedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(
                    'Failed to load stats\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            final items = (snapshot.data?.docs ?? [])
                .map(CashGameSessionItem.fromDoc)
                .toList();

            final endedItems =
                items.where((e) => !e.isOngoing && e.endedAt != null).toList();

            final totalProfit = endedItems.fold<double>(
              0,
              (sum, item) => sum + item.profit,
            );

            final totalHours = endedItems.fold<double>(
              0,
              (sum, item) => sum + item.hours,
            );

            final sessionsCount = endedItems.length;

            final hourly =
                totalHours <= 0 ? 0.0 : totalProfit / totalHours;

            final perSession =
                sessionsCount == 0 ? 0.0 : totalProfit / sessionsCount;

            final winningCount =
                endedItems.where((e) => e.profit > 0).length;

            final groupedByLocation = _buildGroupedData(
              endedItems,
              (item) => item.location.isEmpty
                  ? 'Unknown'
                  : _normalizeLocationForDisplay(item.location),
            );

            final groupedByGame = _buildGroupedData(
              endedItems,
              (item) => item.gameLabel.isEmpty ? 'Unknown' : item.gameLabel,
            );

            final groupedByWeekday = _buildGroupedData(
              endedItems,
              (item) => _weekdayZh(item.startedAt),
            );

            final groupedByMonth = _buildGroupedData(
              endedItems,
              (item) =>
                  '${item.startedAt.year}/${item.startedAt.month.toString().padLeft(2, '0')}',
            );

            Widget buildGroupList(Map<String, Map<String, double>> grouped) {
              final entries = grouped.entries.toList()
                ..sort((a, b) =>
                    (b.value['profit'] ?? 0).compareTo(a.value['profit'] ?? 0));

              if (entries.isEmpty) {
                return const Center(
                  child: Text('No data yet'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final profit = entry.value['profit'] ?? 0.0;
                  final hours = entry.value['hours'] ?? 0.0;
                  final hourly = hours <= 0 ? 0.0 : profit / hours;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _moneyShortText(profit),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _profitColor(profit),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _profitColor(hourly),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '\$/${_hourText(hourly)}/hr',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            Widget buildAllSessions() {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 720 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildSummaryCard(
                        label: 'Profit/Loss',
                        value: _moneyText(totalProfit),
                        color: _profitColor(totalProfit),
                      ),
                      _buildSummaryCard(
                        label: '\$/Hour',
                        value: _moneyText(hourly),
                        color: _profitColor(hourly),
                      ),
                      _buildSummaryCard(
                        label: '\$/Game',
                        value: _moneyText(perSession),
                        color: _profitColor(perSession),
                      ),
                      _buildSummaryCard(
                        label: 'Spending Time',
                        value: '${_hourText(totalHours)} Hour',
                        color: Colors.black87,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Win Rate',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${winningCount}/${sessionsCount} '
                          '(${sessionsCount == 0 ? 0 : ((winningCount / sessionsCount) * 100).round()}%)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Center(
                        child: Text(
                          'No hand data yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  for (final item in items) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _openEditor(item: item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.location.isEmpty
                                        ? 'Unknown Location'
                                        : _normalizeLocationForDisplay(item.location),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_hourText(item.hours)}h - ${item.gameLabel}',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _dateText(item.startedAt),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.isOngoing)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Is Ongoing',
                                        style: TextStyle(
                                          color: Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _moneyText(item.profit),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _profitColor(item.profit),
                                ),
                              ),
                              const SizedBox(height: 10),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    _openEditor(item: item);
                                  } else if (value == 'delete') {
                                    await _deleteSession(item.id);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }

            return TabBarView(
              children: [
                buildAllSessions(),
                buildGroupList(groupedByLocation),
                buildGroupList(groupedByGame),
                buildGroupList(groupedByWeekday),
                buildGroupList(groupedByMonth),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CashGameSessionEditorPage extends StatefulWidget {
  final CashGameSessionItem? item;

  const CashGameSessionEditorPage({
    super.key,
    this.item,
  });

  @override
  State<CashGameSessionEditorPage> createState() =>
      _CashGameSessionEditorPageState();
}

class _CashGameSessionEditorPageState extends State<CashGameSessionEditorPage> {
  late final TextEditingController gameController;
  late final TextEditingController stakesController;
  late final TextEditingController locationController;
  late final TextEditingController buyInController;
  late final TextEditingController cashOutController;
  late final TextEditingController tipsController;
  late final TextEditingController noteController;

  late DateTime startedAt;
  DateTime? endedAt;
  bool isOngoing = false;
  bool isSaving = false;
  CashGameLocationType locationType = CashGameLocationType.homeGame;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    final initialLocation = item?.location ?? '';

    locationType = _detectLocationType(initialLocation);

    gameController = TextEditingController(
      text: item?.game ?? 'Texas Holdem',
    );
    stakesController = TextEditingController(
      text: item?.stakes ?? '2/5',
    );
    locationController = TextEditingController(
      text: _extractEditableLocationName(initialLocation),
    );
    buyInController = TextEditingController(
      text: item == null ? '' : item.buyIn.toStringAsFixed(2),
    );
    cashOutController = TextEditingController(
      text: item == null ? '' : item.cashOut.toStringAsFixed(2),
    );
    tipsController = TextEditingController(
      text: item == null ? '0' : item.tips.toStringAsFixed(2),
    );
    noteController = TextEditingController(
      text: item?.note ?? '',
    );

    startedAt = item?.startedAt ?? DateTime.now();
    endedAt = item?.endedAt;
    isOngoing = item?.isOngoing ?? false;
  }

  String _buildFormattedLocation() {
    final name = locationController.text.trim();

    if (name.isEmpty) {
      return '';
    }

    if (locationType == CashGameLocationType.casino) {
      return '$name Casino';
    }

    return "$name's Game";
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startedAt),
    );

    if (!mounted || time == null) return;

    setState(() {
      startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickEndTime() async {
    final initial = endedAt ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (!mounted || time == null) return;

    setState(() {
      endedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _deleteGame() async {
    if (widget.item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Game'),
          content: const Text('Are you sure you want to delete this game?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('cash_game_sessions')
        .doc(widget.item!.id)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game deleted')),
    );

    Navigator.pop(context);
  }

  Future<void> _save() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (userUid.isEmpty) {
      return;
    }

    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the location')),
      );
      return;
    }

    if (!isOngoing && endedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the end time')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final formattedLocation = _buildFormattedLocation();

    final data = {
      'userUid': userUid,
      'game': gameController.text.trim(),
      'stakes': stakesController.text.trim(),
      'location': formattedLocation,
      'buyIn': _toDouble(buyInController.text.trim()),
      'cashOut': _toDouble(cashOutController.text.trim()),
      'tips': _toDouble(tipsController.text.trim()),
      'note': noteController.text.trim(),
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': isOngoing || endedAt == null
          ? null
          : Timestamp.fromDate(endedAt!),
      'isOngoing': isOngoing,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.item == null) {
        await FirebaseFirestore.instance.collection('cash_game_sessions').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('cash_game_sessions')
            .doc(widget.item!.id)
            .set(data, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save')),
      );

      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    gameController.dispose();
    stakesController.dispose();
    locationController.dispose();
    buyInController.dispose();
    cashOutController.dispose();
    tipsController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Game' : 'Add Game',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _deleteGame,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Game',
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: gameController,
              decoration: const InputDecoration(
                labelText: 'Game',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stakesController,
              decoration: const InputDecoration(
                labelText: 'Stakes',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CashGameLocationType>(
              value: locationType,
              decoration: const InputDecoration(
                labelText: 'Location Type',
              ),
              items: const [
                DropdownMenuItem(
                  value: CashGameLocationType.homeGame,
                  child: Text('Home Game'),
                ),
                DropdownMenuItem(
                  value: CashGameLocationType.casino,
                  child: Text('Casino'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  locationType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: locationType == CashGameLocationType.casino
                    ? 'Casino Name'
                    : 'Player Name',
                hintText: locationType == CashGameLocationType.casino
                    ? 'Enter casino name'
                    : 'Enter player name',
                helperText: locationType == CashGameLocationType.casino
                    ? 'Will save as: Name Casino'
                    : "Will save as: Name's Game",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: buyInController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Buy In',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashOutController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cash Out',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tipsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tips',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: isOngoing,
              title: const Text('Is Ongoing'),
              onChanged: (value) {
                setState(() {
                  isOngoing = value;
                  if (isOngoing) {
                    endedAt = null;
                  }
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(_dateTimeText(startedAt)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickStartTime,
            ),
            if (!isOngoing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End'),
                subtitle: Text(
                  endedAt == null ? 'Please choose' : _dateTimeText(endedAt!),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: _pickEndTime,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isSaving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  isSaving ? 'Saving...' : 'Save',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}