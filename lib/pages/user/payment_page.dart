import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/payment_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/background.dart';
import 'package:gamezone/widgets/common/status_badge.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final PaymentService _paymentService = PaymentService();

  Map<String, dynamic> _bookingData = {};
  bool _isRouteInitialized = false;

  Timer? _countdownTimer;
  int _remainingSeconds = 15 * 60; // fallback jika createdAt tidak tersedia
  bool _isExpired = false;
  bool _isLoading = false;
  bool _hasTriggeredExpiry =
      false; // guard agar expireBooking hanya dipanggil sekali

  static const int _paymentDurationSeconds = 15 * 60; // 15 menit

  // Metode pembayaran yang tersedia dan state yang dipilih
  static const List<_PaymentMethod> _availableMethods = [
    _PaymentMethod(
      id: 'QRIS',
      label: 'QRIS',
      icon: Icons.qr_code_scanner_rounded,
    ),
    _PaymentMethod(
      id: 'Transfer Bank',
      label: 'Transfer Bank',
      icon: Icons.account_balance_rounded,
    ),
    _PaymentMethod(
      id: 'E-Wallet',
      label: 'E-Wallet',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _PaymentMethod(
      id: 'Virtual Account',
      label: 'Virtual Account',
      icon: Icons.credit_card_rounded,
    ),
  ];

  // Default: QRIS dipilih pertama kali
  String _selectedMethodId = 'QRIS';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteInitialized) {
      _isRouteInitialized = true;
      final Object? arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map<String, dynamic>) {
        _bookingData = arguments;
      }
      _initCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Hitung sisa waktu pembayaran.
  ///
  /// Prioritas sumber waktu:
  ///   1. createdAtMillis dari arguments route (tersedia saat baru booking)
  ///   2. Fetch field createdAt dari Firestore (tersedia saat buka dari riwayat)
  ///   3. Fallback 15 menit penuh (booking lama tanpa field createdAt)
  ///
  /// expiredAt = createdAt + 15 menit
  /// remainingSeconds = max(0, expiredAt - now)
  void _initCountdown() {
    final int? createdAtMillis = _bookingData['createdAtMillis'] as int?;

    if (createdAtMillis != null) {
      // Sumber 1: tersedia langsung dari arguments
      _applyCreatedAt(createdAtMillis);
    } else {
      // Sumber 2: fetch dari Firestore lalu mulai timer
      final String bookingId = _bookingData['bookingId']?.toString() ?? '';
      if (bookingId.isNotEmpty) {
        _fetchCreatedAtAndStart(bookingId);
      } else {
        // Sumber 3: fallback
        _startTimer();
      }
    }
  }

  /// Fetch createdAt dari Firestore untuk bookingId yang diberikan,
  /// lalu inisialisasi countdown sesuai sisa waktu.
  Future<void> _fetchCreatedAtAndStart(String bookingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Cek apakah booking sudah dibayar / expired di Firestore
        final String statusBayar = (data['statusPembayaran'] ?? '')
            .toString()
            .toLowerCase();
        if (statusBayar == 'paid') {
          // Sudah dibayar dari device lain atau session sebelumnya
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/user-dashboard',
            (route) => false,
            arguments: {'initialTabIndex': 3},
          );
          return;
        }
        if (statusBayar == 'expired' || statusBayar == 'cancelled') {
          setState(() {
            _remainingSeconds = 0;
            _isExpired = true;
          });
          return;
        }

        final dynamic rawCreatedAt = data['createdAt'];
        if (rawCreatedAt is Timestamp) {
          _applyCreatedAt(rawCreatedAt.toDate().millisecondsSinceEpoch);
          return;
        }
      }
    } catch (e) {
      debugPrint('PaymentPage: gagal fetch createdAt — $e');
    }

    // Fallback jika fetch gagal atau createdAt tidak ada
    if (mounted) _startTimer();
  }

  /// Hitung remaining dari createdAtMillis dan mulai timer.
  void _applyCreatedAt(int createdAtMillis) {
    final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
      createdAtMillis,
    );
    final DateTime expiredAt = createdAt.add(
      const Duration(seconds: _paymentDurationSeconds),
    );
    final int remaining = expiredAt.difference(DateTime.now()).inSeconds;

    if (remaining <= 0) {
      setState(() {
        _remainingSeconds = 0;
        _isExpired = true;
      });
      _triggerExpiry();
      return;
    }

    setState(() {
      _remainingSeconds = remaining;
    });
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        if (!_isExpired) {
          setState(() => _isExpired = true);
          _triggerExpiry();
        }
      }
    });
  }

  /// Tandai booking sebagai expired + cancelled di Firestore.
  /// Guard _hasTriggeredExpiry memastikan ini hanya dipanggil sekali
  /// meskipun halaman dibuka ulang beberapa kali setelah waktu habis.
  void _triggerExpiry() {
    if (_hasTriggeredExpiry) return;
    _hasTriggeredExpiry = true;

    final String bookingId = _bookingData['bookingId'] ?? '';
    if (bookingId.isEmpty) return;

    _paymentService.expireBooking(bookingId);
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int value) {
    if (value <= 0) return 'Rp 0';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _handlePayment() async {
    final String bookingId = _bookingData['bookingId'] ?? '';
    if (bookingId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Kirim metode yang dipilih user ke service
      await _paymentService.simulatePayment(
        bookingId,
        metodePembayaran: _selectedMethodId,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil.'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      // Redirect ke Riwayat Booking (tab index 3 di UserDashboardPage)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/user-dashboard',
        (route) => false,
        arguments: {'initialTabIndex': 3},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran gagal diproses.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showSimulasiDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.primaryDarkNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColors.accentCyan.withValues(alpha: 0.15),
            ),
          ),
          title: Text(
            'Simulasi Pembayaran',
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Apakah Anda ingin menyelesaikan pembayaran ini?',
            style: AppTextStyle.body2.copyWith(color: AppColors.softGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Batal',
                style: AppTextStyle.buttonMedium.copyWith(
                  color: AppColors.lightText,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(dialogContext);
                _handlePayment();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.paddingL,
                  vertical: AppTheme.paddingM,
                ),
                decoration: BoxDecoration(
                  gradient: Gradients.kAccent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  'Bayar',
                  style: AppTextStyle.buttonMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalHarga = _bookingData['totalHarga'] ?? 0;
    final String bookingId = _bookingData['bookingId'] ?? '-';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusBadge(),
                      const SizedBox(height: 16),
                      _buildTotalCard(totalHarga, bookingId),
                      const SizedBox(height: 16),
                      _buildQrisCard(),
                      const SizedBox(height: 16),
                      _buildPaymentMethods(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF141B31),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF23304C)),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Pembayaran',
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status Badge ────────────────────────────────────────────────────────────

  Widget _buildStatusBadge() {
    final Color badgeColor = _isExpired
        ? AppColors.errorRed
        : AppColors.warningOrange;
    final String textLabel = _isExpired
        ? 'PEMBAYARAN KADALUARSA'
        : 'MENUNGGU PEMBAYARAN';

    return Center(
      child: StatusBadge(label: textLabel, color: badgeColor),
    );
  }

  // ─── Total Card ──────────────────────────────────────────────────────────────

  Widget _buildTotalCard(int totalHarga, String bookingId) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Text(
            'Total Pembayaran',
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(totalHarga),
            style: AppTextStyle.h2.copyWith(
              color: AppColors.accentCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID Booking',
                style: AppTextStyle.caption1.copyWith(
                  color: AppColors.lightText,
                ),
              ),
              Text(
                '#$bookingId',
                style: AppTextStyle.body2.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── QRIS Card ───────────────────────────────────────────────────────────────

  Widget _buildQrisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingXXL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Text(
            'QRIS',
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan untuk melakukan pembayaran.',
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
          const SizedBox(height: 20),
          // QR code area — white background agar QR terbaca scanner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Image.asset(
              'assets/images/qris_dummy.png',
              height: 200,
              width: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return SizedBox(
                  height: 200,
                  width: 200,
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 120,
                    color: Colors.black87,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Countdown / expired label
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingL,
              vertical: AppTheme.paddingS,
            ),
            decoration: BoxDecoration(
              color: (_isExpired ? AppColors.errorRed : AppColors.warningOrange)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color:
                    (_isExpired ? AppColors.errorRed : AppColors.warningOrange)
                        .withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _isExpired
                  ? 'PEMBAYARAN KADALUARSA'
                  : 'Berlaku Dalam ${_formatTime(_remainingSeconds)}',
              style: AppTextStyle.caption1.copyWith(
                color: _isExpired
                    ? AppColors.errorRed
                    : AppColors.warningOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Payment Methods ─────────────────────────────────────────────────────────

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metode Pembayaran',
          style: AppTextStyle.h4.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih metode pembayaran yang tersedia.',
          style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
        ),
        const SizedBox(height: 12),
        ..._availableMethods.map((method) => _buildMethodItem(method)),
      ],
    );
  }

  Widget _buildMethodItem(_PaymentMethod method) {
    final bool isSelected = _selectedMethodId == method.id;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedMethodId = method.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingL,
          vertical: AppTheme.paddingM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.08)
              : AppColors.secondaryDark.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected
                ? AppColors.accentCyan.withValues(alpha: 0.55)
                : AppColors.accentCyan.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.1,
          ),
          boxShadow: isSelected ? AppTheme.shadowSoft : null,
        ),
        child: Row(
          children: [
            // Ikon metode
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.accentCyan : AppColors.softGray)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                method.icon,
                color: isSelected ? AppColors.accentCyan : AppColors.softGray,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Label metode
            Expanded(
              child: Text(
                method.label,
                style: AppTextStyle.body2.copyWith(
                  color: isSelected ? AppColors.white : AppColors.softGray,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentCyan
                      : const Color(0xFF475569),
                  width: isSelected ? 0 : 2,
                ),
                color: isSelected ? AppColors.accentCyan : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.primaryDarkNavy,
        border: Border(
          top: BorderSide(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _isExpired || _isLoading
            ? SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.softGray,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Bayar Sekarang',
                          style: AppTextStyle.buttonLarge.copyWith(
                            color: AppColors.softGray,
                          ),
                        ),
                ),
              )
            : GestureDetector(
                onTap: _showSimulasiDialog,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: Gradients.kAccent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.shadowMedium,
                  ),
                  child: Text(
                    'Bayar Sekarang',
                    style: AppTextStyle.buttonLarge.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// Data class untuk tiap pilihan metode pembayaran
class _PaymentMethod {
  final String id;
  final String label;
  final IconData icon;

  const _PaymentMethod({
    required this.id,
    required this.label,
    required this.icon,
  });
}
