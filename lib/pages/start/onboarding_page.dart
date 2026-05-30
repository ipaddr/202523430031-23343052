import 'package:flutter/material.dart';
import '../../widgets/background.dart';
import '../../widgets/startup_widgets.dart';
import '../../styles/app_textstyle.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _current = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'image': 'assets/images/onboarding1.jpg',
      'title': 'Booking Ruangan Game\nJadi Lebih Mudah',
      'subtitle':
          'Cek ketersediaan secara realtime dan dapatkan rekomendasi game terbaik untukmu.',
      'chips': ['Realtime', 'AI Recommend', 'Instant Pay'],
    },
    {
      'image': 'assets/images/onboarding2.jpg',
      'title': 'Temukan Game Station\nTerbaik di Sekitarmu',
      'subtitle':
          'Temukan tempat bermain terbaik dengan fasilitas lengkap, harga terjangkau, dan rating dari pengguna lain.',
      'chips': ['Realtime', 'AI Recommend', 'Instant Pay'],
    },
    {
      'image': 'assets/images/onboarding3.jpg',
      'title': 'Dapatkan Rekomendasi AI\nSesuai Preferensi',
      'subtitle':
          'Personalisasi saran game dan room berdasarkan gaya bermainmu.',
      'chips': ['Realtime', 'AI Recommend', 'Instant Pay'],
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Area gambar (tinggi relatif tetap untuk kartu onboarding)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, index) {
                    final s = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: OnboardingCard(imageAsset: s['image'] as String),
                    );
                  },
                ),
              ),
              // Area konten teks dan tombol
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      SlideIndicator(
                        count: _slides.length,
                        activeIndex: _current,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _slides[_current]['title'] as String,
                        textAlign: TextAlign.center,
                        style: AppTextStyle.h2.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _slides[_current]['subtitle'] as String,
                        textAlign: TextAlign.center,
                        style: AppTextStyle.body2.copyWith(
                          color: const Color(0xFF9AA0C6),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // chip: jarak tetap dari subtitle
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: (_slides[_current]['chips'] as List<String>)
                            .map(
                              (chip) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1D2E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: chip == 'AI Recommend'
                                            ? const Color(0xFFA855F7)
                                            : chip == 'Instant Pay'
                                            ? const Color(0xFF22D3EE)
                                            : const Color(0xFF22D3EE),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      chip,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF14B8FF), Color(0xFF7C4DFF)],
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(26),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Lanjut',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
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
}
