import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/widgets/common/custom_empty_state.dart';
import 'package:gamezone/widgets/common/custom_search_bar.dart';
import 'package:gamezone/widgets/common/filter_pill.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedTab = 'Semua';

  final List<String> _tabs = [
    'Semua',
    'Gaming Center',
    'Esports Center',
    'Console Center',
    'VR Center',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pencarian & Tab Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 14),
              _buildTabFilter(),
            ],
          ),
        ),

        // Area Katalog Grid/List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getStationsByVerificationStatusStream(
              'verified',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState('Gagal memuat katalog stasiun.');
              }

              final allDocs = snapshot.data?.docs ?? [];

              // Pemetaan data mentah ke List map
              final List<Map<String, dynamic>> stations = allDocs.map((doc) {
                final Map<String, dynamic> data =
                    doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              // Filter & Pencarian Sisi Klien
              final filteredStations = stations.where((station) {
                // 1. Filter Tab (jenis)
                final String jenis =
                    station['jenis']?.toString().toLowerCase() ?? '';
                if (_selectedTab != 'Semua' &&
                    jenis != _selectedTab.toLowerCase()) {
                  return false;
                }

                // 2. Query Pencarian
                if (_searchQuery.isNotEmpty) {
                  final String name =
                      (station['namaStation'] ?? station['stationName'] ?? '')
                          .toString()
                          .toLowerCase();
                  final String alamat = (station['alamat'] ?? '')
                      .toString()
                      .toLowerCase();
                  final String stationJenis = (station['jenis'] ?? '')
                      .toString()
                      .toLowerCase();

                  final bool matchesName = name.contains(_searchQuery);
                  final bool matchesAlamat = alamat.contains(_searchQuery);
                  final bool matchesJenis = stationJenis.contains(_searchQuery);

                  if (!matchesName && !matchesAlamat && !matchesJenis) {
                    return false;
                  }
                }

                return true;
              }).toList();

              // Urutkan berdasarkan rating tertinggi secara default
              filteredStations.sort((a, b) {
                final double ratingA = (a['rating'] is num)
                    ? (a['rating'] as num).toDouble()
                    : 0.0;
                final double ratingB = (b['rating'] is num)
                    ? (b['rating'] as num).toDouble()
                    : 0.0;
                return ratingB.compareTo(ratingA);
              });

              // Jika data kosong dari pencarian / filter
              if (filteredStations.isEmpty) {
                if (_searchQuery.isNotEmpty) {
                  return _buildEmptyState(
                    title: 'Tidak ditemukan',
                    description: 'Silakan ubah kata kunci pencarian Anda.',
                    icon: Icons.search_off_rounded,
                  );
                } else {
                  return _buildEmptyState(
                    title: 'Katalog Kosong',
                    description: 'Belum ada game station kategori ini.',
                    icon: Icons.storefront_rounded,
                  );
                }
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: filteredStations.length,
                itemBuilder: (context, index) {
                  return _buildStationCard(filteredStations[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget kolom pencarian
  Widget _buildSearchBar() {
    return CustomSearchBar(
      controller: _searchController,
      hintText: 'Cari game station...',
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      },
    );
  }

  // Widget filter tab
  Widget _buildTabFilter() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final String tabLabel = _tabs[index];
          final bool selected = _selectedTab == tabLabel;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterPill(
              label: tabLabel,
              selected: selected,
              onTap: () {
                setState(() {
                  _selectedTab = tabLabel;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // Widget Kartu Game Station (Desain identik dashboard)
  Widget _buildStationCard(Map<String, dynamic> station) {
    final String name = station['namaStation'] ?? 'Game Station';
    final String alamat = station['alamat'] ?? 'Alamat tidak tersedia';

    final bool hasRating =
        station['rating'] != null &&
        (station['rating'] is num) &&
        (station['rating'] as num) > 0;
    final double rating = hasRating
        ? (station['rating'] as num).toDouble()
        : 0.0;

    final dynamic totalReview = station['totalReview'];
    final String reviewText = (totalReview != null && totalReview != 0)
        ? '$totalReview Review'
        : 'Belum ada review';

    // Ambil foto
    String fotoUrl = '';
    final fotoData = station['foto'];
    if (fotoData is String && fotoData.trim().isNotEmpty) {
      fotoUrl = fotoData.trim();
    } else if (fotoData is List &&
        fotoData.isNotEmpty &&
        fotoData.first != null) {
      fotoUrl = fotoData.first.toString().trim();
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/station-detail',
          arguments: {
            'stationId': station['id']?.toString() ?? '',
            'stationData': station,
            'viewMode': 'user',
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF334155).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              // Foto Station
              SizedBox(
                width: 104,
                height: 104,
                child: fotoUrl.isNotEmpty
                    ? Image.network(
                        fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) =>
                            _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
              // Info Detail
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyle.body1.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tumpukan Rating & Ulasan
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasRating
                                        ? rating.toStringAsFixed(1)
                                        : 'Belum ada rating',
                                    style: AppTextStyle.caption1.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reviewText,
                                style: AppTextStyle.caption2.copyWith(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF94A3B8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              alamat,
                              style: AppTextStyle.caption1.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Color(0xFF475569),
          size: 32,
        ),
      ),
    );
  }

  // Widget tampilan kosong & error
  Widget _buildEmptyState({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return CustomEmptyState(icon: icon, title: title, subtitle: description);
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorRed,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyle.body2.copyWith(color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
