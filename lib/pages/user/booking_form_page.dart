import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/auth_service.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/background.dart';

class BookingFormPage extends StatefulWidget {
  const BookingFormPage({super.key});

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRouteInitialized = false;
  bool _isLoading = false;
  bool _checkingAvailability = false;
  bool _loadingStation = false;

  String _unitId = '';
  String _stationId = '';
  Map<String, dynamic> _unitData = {};
  Map<String, dynamic>? _stationData;

  // Stream subscription untuk data station realtime
  StreamSubscription<DocumentSnapshot>? _stationSubscription;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime; // Jam Mulai
  TimeOfDay? _endTime; // Jam Selesai

  List<Map<String, dynamic>> _existingBookings = [];
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteInitialized) return;
    _isRouteInitialized = true;
    _parseRouteArguments();
    _subscribeStationData();
  }

  @override
  void dispose() {
    _stationSubscription?.cancel();
    super.dispose();
  }

  void _parseRouteArguments() {
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _unitId = args['unitId']?.toString() ?? '';
      _stationId = args['stationId']?.toString() ?? '';
      final rawData = args['unitData'];
      if (rawData is Map<String, dynamic>) {
        _unitData = rawData;
      } else if (rawData is Map) {
        _unitData = rawData.map((k, v) => MapEntry(k.toString(), v));
      }
    }
  }

  /// Berlangganan stream realtime data station dari Firestore.
  /// Setiap kali admin mengubah jam operasional, widget ini otomatis
  /// menerima data terbaru tanpa perlu fetch ulang secara manual.
  void _subscribeStationData() {
    if (_stationId.isEmpty) return;

    setState(() {
      _loadingStation = true;
    });

    _stationSubscription = _firestoreService
        .getStationStream(_stationId)
        .listen(
          (snapshot) {
            if (!mounted) return;
            final data = snapshot.data() as Map<String, dynamic>?;
            setState(() {
              _stationData = data;
              _loadingStation = false;
            });
            // Jalankan ulang validasi jadwal agar error/warning langsung
            // diperbarui berdasarkan jam operasional terbaru.
            if (_selectedTime != null || _endTime != null) {
              _validateSchedule();
            }
          },
          onError: (Object e) {
            debugPrint('Gagal memuat data stasiun: $e');
            if (!mounted) return;
            setState(() {
              _loadingStation = false;
            });
          },
        );
  }

  String _formatDate(DateTime date) {
    final List<String> days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateToDb(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _timeToMinutes(String timeStr) {
    try {
      final String cleanStr = timeStr.replaceAll('.', ':');
      final parts = cleanStr.split(':');
      final int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  String _formatCurrency(int value) {
    if (value <= 0) return 'Rp 0';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  double _calculateDurationInHours() {
    if (_selectedTime == null || _endTime == null) return 0.0;
    final int startMin = _selectedTime!.hour * 60 + _selectedTime!.minute;
    final int endMin = _endTime!.hour * 60 + _endTime!.minute;
    if (endMin <= startMin) return 0.0;
    return (endMin - startMin) / 60.0;
  }

  Map<String, dynamic>? _getScheduleForSelectedDate() {
    if (_selectedDate == null || _stationData == null) return null;
    final List<dynamic> scheduleList = _stationData!['jamOperasional'] ?? [];
    final List<String> daysEngToInd = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final String dayName = daysEngToInd[_selectedDate!.weekday - 1];

    for (final day in scheduleList) {
      if (day is Map &&
          day['hari']?.toString().toLowerCase() == dayName.toLowerCase()) {
        return Map<String, dynamic>.from(day);
      }
    }
    return null;
  }

  // Firestore Booking & Conflict Checker
  Future<void> _fetchAndValidateBookings() async {
    if (_selectedDate == null || _selectedTime == null || _endTime == null) {
      return;
    }

    setState(() {
      _checkingAvailability = true;
      _errorMessage = null;
    });

    try {
      final String dbDateStr = _formatDateToDb(_selectedDate!);

      // Ambil booking dari Firestore untuk unit ini pada tanggal terpilih
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('unitId', isEqualTo: _unitId)
          .where('tanggalBooking', isEqualTo: dbDateStr)
          .get();

      final List<Map<String, dynamic>> allBookings = snap.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      final DateTime now = DateTime.now();
      _existingBookings = allBookings.where((booking) {
        final String statusBooking = (booking['statusBooking'] ?? '')
            .toString()
            .toLowerCase();
        final String statusPembayaran = (booking['statusPembayaran'] ?? '')
            .toString()
            .toLowerCase();

        // 1. Halaman / Status yang dibatalkan, ditolak, selesai tidak memblokir slot
        if (statusBooking == 'cancelled' ||
            statusBooking == 'rejected' ||
            statusBooking == 'completed' ||
            statusBooking == 'expired' ||
            statusPembayaran == 'expired' ||
            statusPembayaran == 'cancelled') {
          return false;
        }

        // 2. Booking yang status pembayaran 'paid' memblokir slot
        if (statusPembayaran == 'paid') {
          return true;
        }

        // 3. Booking pending + unpaid memblokir slot jika berumur kurang dari 15 menit
        if (statusBooking == 'pending' && statusPembayaran == 'unpaid') {
          final dynamic rawCreated = booking['createdAt'];
          DateTime? createdAt;
          if (rawCreated is Timestamp) {
            createdAt = rawCreated.toDate();
          } else if (rawCreated is DateTime) {
            createdAt = rawCreated;
          }
          if (createdAt != null) {
            final Duration age = now.difference(createdAt);
            if (age.inMinutes < 15) {
              return true;
            }
          }
        }

        // 4. Status lain yang aktif memblokir slot secara eksplisit
        if (statusBooking == 'pending_confirmation' ||
            statusBooking == 'confirmed' ||
            statusBooking == 'active' ||
            statusBooking == 'checkin') {
          return true;
        }

        return false;
      }).toList();

      _validateSchedule();
    } catch (e) {
      debugPrint('Gagal memverifikasi jadwal stasiun: $e');
      _existingBookings = [];
      _validateSchedule();
    } finally {
      setState(() {
        _checkingAvailability = false;
      });
    }
  }

  void _validateSchedule() {
    // 1. Validasi Hari Operasional
    final schedule = _getScheduleForSelectedDate();
    if (schedule != null) {
      final bool isOpen = schedule['isOpen'] as bool? ?? true;
      if (!isOpen) {
        setState(() {
          _errorMessage = 'Game Station tutup pada hari yang dipilih.';
        });
        return;
      }
    }

    if (_selectedTime == null || _endTime == null) return;

    final int userStartMin = _selectedTime!.hour * 60 + _selectedTime!.minute;
    final int userEndMin = _endTime!.hour * 60 + _endTime!.minute;

    // Tambahan Validasi: Hari & Jam yang sudah lewat
    if (_selectedDate != null) {
      final DateTime now = DateTime.now();
      if (_selectedDate!.year == now.year &&
          _selectedDate!.month == now.month &&
          _selectedDate!.day == now.day) {
        final int currentMin = now.hour * 60 + now.minute;
        if (userStartMin < currentMin) {
          setState(() {
            _errorMessage = 'Jam mulai sudah lewat.';
          });
          return;
        }
      }
    }

    // 2. Validasi Jam Buka / Jam Tutup Stasiun
    if (schedule != null) {
      final String bukaStr = (schedule['buka'] ?? '00.00').toString();
      final String tutupStr = (schedule['tutup'] ?? '00.00').toString();

      final int openMin = _timeToMinutes(bukaStr);
      final int closeMin = _timeToMinutes(tutupStr);

      if (userStartMin < openMin) {
        setState(() {
          _errorMessage = 'Jam mulai berada di luar jam operasional.';
        });
        return;
      }

      if (userEndMin > closeMin) {
        setState(() {
          _errorMessage = 'Jam selesai melebihi jam operasional.';
        });
        return;
      }
    }

    // 3. Validasi Waktu: Jam selesai harus lebih besar dari jam mulai
    if (userEndMin <= userStartMin) {
      setState(() {
        _errorMessage = 'Jam selesai harus lebih besar dari jam mulai.';
      });
      return;
    }

    // 4. Validasi Minimal: Durasi bermain minimal 1 jam
    final int durationMinutes = userEndMin - userStartMin;
    if (durationMinutes < 60) {
      setState(() {
        _errorMessage = 'Durasi bermain minimal 1 jam.';
      });
      return;
    }

    // 5. Validasi Bentrok Jadwal dengan Booking Lain
    for (final booking in _existingBookings) {
      final String startStr = booking['jamMulai']?.toString() ?? '00:00';
      final String endStr = booking['jamSelesai']?.toString() ?? '00:00';

      final int existStartMin = _timeToMinutes(startStr);
      final int existEndMin = _timeToMinutes(endStr);

      // Terjadi tabrakan jika irisan rentang waktu terpenuhi
      if (userStartMin < existEndMin && userEndMin > existStartMin) {
        setState(() {
          _errorMessage = 'Jadwal tersebut sudah dibooking.';
        });
        return;
      }
    }

    setState(() {
      _errorMessage = null;
    });
  }

  // Aksi untuk pemilih (picker) tanggal dan waktu
  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _selectedDate ?? now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              onPrimary: Colors.black,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F172A),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset jam mulai
        _endTime = null; // Reset jam selesai
        _errorMessage = null;
      });
      _validateSchedule();
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih tanggal terlebih dahulu.'),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    final schedule = _getScheduleForSelectedDate();
    if (schedule != null) {
      final bool isOpen = schedule['isOpen'] as bool? ?? true;
      if (!isOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game Station tutup pada hari yang dipilih.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
    }

    final TimeOfDay initialTime = isStart
        ? (_selectedTime ?? TimeOfDay.now())
        : (_endTime ?? TimeOfDay.now());

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF0F172A),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedTime = picked;
        } else {
          _endTime = picked;
        }
      });
      await _fetchAndValidateBookings();
    }
  }

  // Submit Booking
  Future<void> _submitBooking() async {
    if (_selectedDate == null ||
        _selectedTime == null ||
        _endTime == null ||
        _errorMessage != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Validasi ulang ketersediaan tepat sebelum submit untuk menghindari race condition
    await _fetchAndValidateBookings();
    if (!mounted) return;
    if (_errorMessage != null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // LEVEL 2 & 3: Cek status unit terbaru di Firestore sebelum booking dibuat
    final String unitId = _unitId;
    if (unitId.isNotEmpty) {
      try {
        final DocumentSnapshot unitSnap = await _firestoreService.getUnitById(
          unitId,
        );
        if (unitSnap.exists) {
          final Map<String, dynamic> currentUnitData =
              unitSnap.data() as Map<String, dynamic>? ?? {};
          final String currentStatus = (currentUnitData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (currentStatus == 'perawatan' ||
              currentStatus == 'maintenance' ||
              currentStatus == 'tidak_aktif' ||
              currentStatus == 'tidak_tersedia' ||
              currentStatus == 'inactive') {
            setState(() {
              _isLoading = false;
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unit tidak tersedia untuk dipesan.'),
                backgroundColor: AppColors.errorRed,
              ),
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('Gagal memverifikasi status unit: $e');
      }
    }

    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi telah berakhir. Silakan login kembali.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Ambil profile user saat ini untuk menyalin nama
      final userSnap = await _firestoreService
          .getUserStream(currentUser.uid)
          .first;
      final userData = userSnap.data() as Map<String, dynamic>? ?? {};

      final String userName = userData['nama'] ?? 'Gamers';
      final String userFoto = userData['foto'] ?? '';

      final int pricePerJam = _unitData['hargaPerJam'] is int
          ? _unitData['hargaPerJam']
          : int.tryParse(_unitData['hargaPerJam']?.toString() ?? '0') ?? 0;

      final double durationHours = _calculateDurationInHours();
      final int totalHarga = (durationHours * pricePerJam).toInt();
      final int durasiJam = durationHours.ceil();

      // Ambil namaStation dari data station (Firestore stations/{stationId}),
      // bukan dari unitData yang tidak menyimpan field namaStation.
      final String namaStation =
          _stationData?['namaStation']?.toString() ??
          _unitData['namaStation']?.toString() ??
          'Game Station';
      final String namaUnit = _unitData['namaUnit']?.toString() ?? 'Unit';
      final String tanggalBooking = _formatDateToDb(_selectedDate!);
      final String jamMulai = _formatTimeOfDay(_selectedTime!);
      final String jamSelesai = _formatTimeOfDay(_endTime!);

      // Generate bookingId terlebih dahulu agar bisa dikirim ke PaymentPage
      final String bookingId = _firestoreService.generateBookingId();

      // Rekam waktu booking dibuat — dipakai PaymentPage untuk hitung
      // sisa countdown dari createdAt, bukan dari nol setiap kali halaman dibuka.
      final DateTime bookingCreatedAt = DateTime.now();

      final Map<String, dynamic> bookingPayload = {
        'bookingId': bookingId,
        'userId': currentUser.uid,
        'namaUser': userName,
        'fotoUser': userFoto,
        'stationId': _stationId,
        'namaStation': namaStation,
        'unitId': _unitId,
        'namaUnit': namaUnit,
        'tanggalBooking': tanggalBooking,
        'jamMulai': jamMulai,
        'jamSelesai': jamSelesai,
        'durasiJam': durasiJam,
        'totalHarga': totalHarga,
        'statusBooking': 'pending',
        'statusPembayaran': 'unpaid',
        'createdAt': Timestamp.fromDate(bookingCreatedAt),
      };

      // Simpan booking ke Firestore sebelum masuk ke halaman pembayaran
      await _firestoreService.createBooking(bookingPayload);

      if (!mounted) return;

      // Langsung redirect ke PaymentPage dengan data booking lengkap.
      // createdAtMillis dikirim agar PaymentPage bisa hitung sisa waktu
      // dari timestamp asli booking, bukan dari nol.
      Navigator.pushNamed(
        context,
        '/payment',
        arguments: {
          'bookingId': bookingId,
          'stationId': _stationId,
          'unitId': _unitId,
          'namaStation': namaStation,
          'namaUnit': namaUnit,
          'tanggalBooking': tanggalBooking,
          'jamMulai': jamMulai,
          'jamSelesai': jamSelesai,
          'durasiJam': durasiJam,
          'totalHarga': totalHarga,
          'createdAtMillis': bookingCreatedAt.millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengajukan booking: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // UI Rendering
  @override
  Widget build(BuildContext context) {
    final int pricePerJam = _unitData['hargaPerJam'] is int
        ? _unitData['hargaPerJam']
        : int.tryParse(_unitData['hargaPerJam']?.toString() ?? '0') ?? 0;

    final double durationHours = _calculateDurationInHours();
    final int totalHarga = (durationHours * pricePerJam).toInt();

    final bool showSummary =
        _selectedDate != null &&
        _selectedTime != null &&
        _endTime != null &&
        _errorMessage == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),

                  // Form Area
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      children: [
                        // Detail unit ringkas
                        _buildUnitBriefCard(),
                        const SizedBox(height: 16),

                        // Card Jam Operasional Lengkap
                        _buildOperationalHoursCard(),

                        // Input Pemilihan
                        _buildFormCard(),
                        const SizedBox(height: 16),

                        // Ringkasan Booking
                        if (showSummary)
                          _buildSummaryCard(
                            pricePerJam,
                            totalHarga,
                            durationHours,
                          ),

                        const SizedBox(height: 24),

                        // Submit Button
                        _buildSubmitButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Form Booking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitBriefCard() {
    final String unitName = _unitData['namaUnit'] ?? 'Unit';
    final String type =
        (_unitData['jenisRoom'] ?? _unitData['jenisUnit'] ?? 'PC').toString();
    final int price = _unitData['hargaPerJam'] is int
        ? _unitData['hargaPerJam']
        : int.tryParse(_unitData['hargaPerJam']?.toString() ?? '0') ?? 0;
    final String priceText = _formatCurrency(price);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          const Icon(
            Icons.meeting_room_rounded,
            color: AppColors.accentCyan,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unitName,
                  style: AppTextStyle.body1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$type • $priceText / jam',
                  style: AppTextStyle.body3.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final schedule = _getScheduleForSelectedDate();
    final bool isStationOpen =
        schedule == null || (schedule['isOpen'] as bool? ?? true);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PILIH TANGGAL
          const Text(
            'TANGGAL BERMAIN',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildPickerButton(
            label: _selectedDate == null
                ? 'Pilih Tanggal'
                : _formatDate(_selectedDate!),
            icon: Icons.calendar_month_rounded,
            onTap: () => _selectDate(context),
          ),
          if (_selectedDate != null && schedule != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                schedule['isOpen'] == true
                    ? 'Jam Operasional: ${(schedule['buka'] ?? '').toString().replaceAll(':', '.')} - ${(schedule['tutup'] ?? '').toString().replaceAll(':', '.')}'
                    : 'Status Hari Ini: TUTUP',
                style: AppTextStyle.caption2.copyWith(
                  color: schedule['isOpen'] == true
                      ? AppColors.accentCyan
                      : AppColors.errorRed,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // PILIH JAM MULAI
          const Text(
            'JAM MULAI',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildPickerButton(
            label: _selectedTime == null
                ? 'Pilih Jam Mulai'
                : _formatTimeOfDay(_selectedTime!),
            icon: Icons.access_time_rounded,
            onTap: isStationOpen ? () => _selectTime(context, true) : null,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Durasi minimum pemesanan adalah 1 jam.',
              style: AppTextStyle.caption2.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // PILIH JAM SELESAI
          const Text(
            'JAM SELESAI',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildPickerButton(
            label: _endTime == null
                ? 'Pilih Jam Selesai'
                : _formatTimeOfDay(_endTime!),
            icon: Icons.access_time_rounded,
            onTap: isStationOpen ? () => _selectTime(context, false) : null,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Jam selesai harus minimal 1 jam setelah jam mulai.',
              style: AppTextStyle.caption2.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ),

          // Error / Checker Message
          if (_checkingAvailability || _loadingStation)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentCyan,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Memeriksa ketersediaan jadwal...',
                    style: TextStyle(color: AppColors.accentCyan, fontSize: 13),
                  ),
                ],
              ),
            ),

          if (_errorMessage != null &&
              !_checkingAvailability &&
              !_loadingStation)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.errorRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF141B31),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF24304A)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    int pricePerJam,
    int totalHarga,
    double durationHours,
  ) {
    // Format durasi agar tampil sebagai bilangan bulat atau desimal yang cantik
    final String durationText = durationHours % 1 == 0
        ? '${durationHours.toInt()} Jam'
        : '${durationHours.toStringAsFixed(1)} Jam';

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RINGKASAN PEMESANAN',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          _buildSummaryRow('Tanggal', _formatDate(_selectedDate!)),
          const Divider(color: Color(0xFF24304A), height: 20),
          _buildSummaryRow('Jam Mulai', _formatTimeOfDay(_selectedTime!)),
          const Divider(color: Color(0xFF24304A), height: 20),
          _buildSummaryRow('Jam Selesai', _formatTimeOfDay(_endTime!)),
          const Divider(color: Color(0xFF24304A), height: 20),
          _buildSummaryRow('Durasi', durationText),
          const Divider(color: Color(0xFF24304A), height: 20),
          _buildSummaryRow('Harga per Jam', _formatCurrency(pricePerJam)),
          const Divider(color: Color(0xFF24304A), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pembayaran',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatCurrency(totalHarga),
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final schedule = _getScheduleForSelectedDate();
    final bool isStationOpen =
        schedule == null || (schedule['isOpen'] as bool? ?? true);

    final bool isEnabled =
        _selectedDate != null &&
        _selectedTime != null &&
        _endTime != null &&
        _errorMessage == null &&
        isStationOpen &&
        !_isLoading;

    final Widget buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.white,
            ),
          )
        else
          Text(
            'Booking Sekarang',
            style: AppTextStyle.buttonMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: isEnabled ? _submitBooking : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: Gradients.kAccent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isEnabled ? AppTheme.shadowMedium : null,
          ),
          child: buttonChild,
        ),
      ),
    );
  }

  Widget _buildOperationalHoursCard() {
    if (_stationData == null) return const SizedBox.shrink();

    final jamOps = _stationData!['jamOperasional'];
    List<Map<String, dynamic>> hours = [];
    if (jamOps is List) {
      for (final e in jamOps) {
        if (e is Map) {
          hours.add(e.map((k, dynamic v) => MapEntry(k.toString(), v)));
        }
      }
    }

    if (hours.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'JAM OPERASIONAL GAME STATION',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...hours.map((h) {
            final String hari = h['hari']?.toString() ?? '-';
            final String buka = (h['buka'] ?? '-').toString().replaceAll(
              ':',
              '.',
            );
            final String tutup = (h['tutup'] ?? '-').toString().replaceAll(
              ':',
              '.',
            );
            final bool isOpen = h['isOpen'] as bool? ?? true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: isOpen
                        ? AppColors.accentCyan
                        : const Color(0xFF64748B),
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hari,
                      style: AppTextStyle.body3.copyWith(
                        color: isOpen ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Text(
                    isOpen ? '$buka - $tutup' : 'TUTUP',
                    style: AppTextStyle.body3.copyWith(
                      color: isOpen ? AppColors.accentCyan : AppColors.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
