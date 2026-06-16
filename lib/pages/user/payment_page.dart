import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/payment_service.dart';
import 'package:gamezone/services/xendit_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/common/background.dart';
import 'package:gamezone/widgets/common/status_badge.dart';
import 'package:gamezone/utils/helpers.dart';
import 'package:gamezone/widgets/common/page_header.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with WidgetsBindingObserver {
  final PaymentService _paymentService = PaymentService();
  final XenditService _xenditService = XenditService();

  Map<String, dynamic> _bookingData = {};
  bool _isRouteInitialized = false;

  Timer? _countdownTimer;
  int _remainingSeconds = 15 * 60; // fallback jika createdAt tidak tersedia
  bool _isExpired = false;
  bool _isLoading = false;
  bool _hasTriggeredExpiry =
      false; // guard agar expireBooking hanya dipanggil sekali

  String? _xenditInvoiceId;
  String? _xenditInvoiceUrl;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

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
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cek status secara pasif saat kembali ke aplikasi dari browser
      _checkPaymentStatusPassive();
    }
  }

  // Hitung sisa waktu pembayaran.
  void _initCountdown() {
    final int? createdAtMillis = _bookingData['createdAtMillis'] as int?;

    if (createdAtMillis != null) {
      // Sumber 1: tersedia langsung dari arguments
      _applyCreatedAt(createdAtMillis);
    } else {
      // Sumber 2: ambil dari Firestore lalu mulai hitung mundur
      final String bookingId = _bookingData['bookingId']?.toString() ?? '';
      if (bookingId.isNotEmpty) {
        _fetchCreatedAtAndStart(bookingId);
      } else {
        // Sumber 3: fallback
        _startTimer();
      }
    }
  }

  /// Ambil data createdAt dari Firestore untuk bookingId yang diberikan,
  /// lalu inisialisasi hitung mundur sesuai sisa waktu.
  Future<void> _fetchCreatedAtAndStart(String bookingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Periksa apakah booking sudah dibayar / kedaluwarsa di Firestore
        final String statusBayar = (data['statusPembayaran'] ?? '')
            .toString()
            .toLowerCase();
        if (statusBayar == 'paid') {
          // Sudah dibayar dari perangkat lain atau sesi sebelumnya
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

        // Ambil data Xendit Invoice jika ada
        _xenditInvoiceId = data['xenditInvoiceId']?.toString();
        _xenditInvoiceUrl = data['xenditInvoiceUrl']?.toString();

        // Pemicu cek pasif jika invoice sudah ada saat masuk halaman
        if (_xenditInvoiceId != null && _xenditInvoiceId!.isNotEmpty) {
          _checkPaymentStatusPassive();
        }

        final dynamic rawCreatedAt = data['createdAt'];
        if (rawCreatedAt is Timestamp) {
          _applyCreatedAt(rawCreatedAt.toDate().millisecondsSinceEpoch);
          return;
        }
      }
    } catch (e) {
      debugPrint(
        '[Payment] Gagal mengambil data waktu pembuatan (createdAt): $e',
      );
    }

    // Fallback jika pengambilan gagal atau createdAt tidak ada
    if (mounted) _startTimer();
  }

  // Hitung sisa waktu dari createdAtMillis dan mulai hitung mundur.
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
        
        // Polling status secara pasif setiap 5 detik jika invoice sudah dibuat
        if (_xenditInvoiceId != null && 
            _xenditInvoiceId!.isNotEmpty && 
            _remainingSeconds % 5 == 0 && 
            !_isLoading) {
          _checkPaymentStatusPassive();
        }
      } else {
        timer.cancel();
        if (!_isExpired) {
          setState(() => _isExpired = true);
          _triggerExpiry();
        }
      }
    });
  }

  /// Tandai booking sebagai kedaluwarsa + dibatalkan di Firestore.
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

  String _formatCurrency(int value) => formatCurrency(value);

  Future<void> _handlePayment() async {
    final String bookingId = _bookingData['bookingId'] ?? '';
    if (bookingId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (_xenditInvoiceUrl != null && _xenditInvoiceUrl!.isNotEmpty) {
        final Uri url = Uri.parse(_xenditInvoiceUrl!);
        await launchUrl(url, mode: LaunchMode.externalApplication);
        setState(() => _isLoading = false);
        return;
      }

      final String payerEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final String stationName = _bookingData['namaStation']?.toString() ?? 'Game Station';
      final int totalHarga = _bookingData['totalHarga'] ?? 0;

      final invoiceData = await _xenditService.createInvoice(
        bookingId: bookingId,
        amount: totalHarga,
        payerEmail: payerEmail,
        stationName: stationName,
      );

      if (invoiceData != null) {
        final String invoiceId = invoiceData['invoice_id'] ?? '';
        final String invoiceUrl = invoiceData['invoice_url'] ?? '';

        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'xenditInvoiceId': invoiceId,
          'xenditInvoiceUrl': invoiceUrl,
        });

        setState(() {
          _xenditInvoiceId = invoiceId;
          _xenditInvoiceUrl = invoiceUrl;
        });

        final Uri url = Uri.parse(invoiceUrl);
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Gagal membuat invoice Xendit.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran gagal diproses: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Memeriksa status pembayaran secara pasif tanpa mengubah state loader utama (_isLoading)
  Future<void> _checkPaymentStatusPassive() async {
    if (_xenditInvoiceId == null || _xenditInvoiceId!.isEmpty || _isExpired) return;

    try {
      final String? status = await _xenditService.checkInvoiceStatus(_xenditInvoiceId!);
      if (status == 'PAID' || status == 'SETTLED') {
        final String bookingId = _bookingData['bookingId'] ?? '';
        
        await _paymentService.simulatePayment(
          bookingId,
          metodePembayaran: 'Xendit',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil dikonfirmasi!'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/user-dashboard',
          (route) => false,
          arguments: {'initialTabIndex': 3},
        );
      } else if (status == 'EXPIRED') {
        final String bookingId = _bookingData['bookingId'] ?? '';
        await _paymentService.expireBooking(bookingId);
        
        if (!mounted) return;
        setState(() {
          _isExpired = true;
          _remainingSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice Xendit telah kadaluarsa.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Payment] Gagal cek status pasif: $e');
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_xenditInvoiceId == null || _xenditInvoiceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda belum membuka halaman pembayaran Xendit.'),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String? status = await _xenditService.checkInvoiceStatus(_xenditInvoiceId!);
      if (status == 'PAID' || status == 'SETTLED') {
        final String bookingId = _bookingData['bookingId'] ?? '';
        
        await _paymentService.simulatePayment(
          bookingId,
          metodePembayaran: 'Xendit',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil dikonfirmasi!'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/user-dashboard',
          (route) => false,
          arguments: {'initialTabIndex': 3},
        );
      } else if (status == 'EXPIRED') {
        final String bookingId = _bookingData['bookingId'] ?? '';
        await _paymentService.expireBooking(bookingId);
        
        if (!mounted) return;
        setState(() {
          _isExpired = true;
          _remainingSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice Xendit telah kadaluarsa.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran belum diterima. Silakan selesaikan pembayaran Anda di Xendit.'),
            backgroundColor: AppColors.warningOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa status pembayaran: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  // Header

  Widget _buildHeader() {
    return const PageHeader(title: 'Pembayaran');
  }

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

  Widget _buildQrisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingXXL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Icon(
            Icons.security_rounded,
            color: AppColors.accentCyan,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            'Xendit Secure Checkout',
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seluruh pembayaran diproses secara aman menggunakan payment gateway Xendit.',
            textAlign: TextAlign.center,
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
          const SizedBox(height: 20),
          // Label hitung mundur / kedaluwarsa
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
          'Pilih metode pembayaran yang tersedia di gerbang Xendit.',
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

            // Indikator radio
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

  Widget _buildBottomBar() {
    final bool hasInvoice = _xenditInvoiceUrl != null && _xenditInvoiceUrl!.isNotEmpty;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.softGray,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (_isExpired)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Text(
                    'Pembayaran Kadaluarsa',
                    style: AppTextStyle.buttonLarge.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                ),
              )
            else ...[
              if (hasInvoice) ...[
                GestureDetector(
                  onTap: _checkPaymentStatus,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.successGreen,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.shadowSoft,
                    ),
                    child: Text(
                      'Konfirmasi Pembayaran',
                      style: AppTextStyle.buttonLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _handlePayment,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.35),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      'Buka Halaman Xendit Lagi',
                      style: AppTextStyle.buttonLarge.copyWith(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _handlePayment,
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
              ]
            ],
          ],
        ),
      ),
    );
  }
}

// Kelas data untuk tiap pilihan metode pembayaran
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
