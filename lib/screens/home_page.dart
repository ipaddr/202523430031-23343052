import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/tflite_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final TfliteService _tfliteService = TfliteService();

  File? _selectedImage;
  String _predictionLabel = 'Belum ada hasil. Yuk unggah foto rempah dulu.';
  double _confidence = 0;
  bool _isModelReady = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _tfliteService.loadModel(
        modelPath: 'assets/model/model_unquant.tflite',
        labelsPath: 'assets/model/labels.txt',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isModelReady = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maaf, model belum berhasil dimuat.\n$error'),
          backgroundColor: const Color(0xFFCB997E),
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

  Future<void> _pickAndClassify(ImageSource source) async {
    if (!_isModelReady || _isLoading) {
      return;
    }

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedImage = File(image.path);
    });

    try {
      final result = await _tfliteService.classifyImage(image.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _predictionLabel = result.label;
        _confidence = result.confidence;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maaf, foto belum bisa diklasifikasikan.\n$error'),
          backgroundColor: const Color(0xFFCB997E),
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

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2E7D32);
    const secondary = Color(0xFF66BB6A);
    const accent = Color(0xFF43A047);
    const text = Color(0xFF1F2D1F);
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = (screenHeight * 0.30).clamp(220.0, 320.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/rempahin_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Rempahin'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4FAF4), Color(0xFFE5F4E7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ayo Cari Tahu Rempahmu!',
                        style: TextStyle(
                          color: text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Unggah foto rempah untuk mulai klasifikasi',
                        style: TextStyle(
                          color: text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tips: pastikan cahaya cukup dan rempah terlihat jelas.',
                        style: TextStyle(
                          color: Color(0xFF3D5A3F),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: secondary, width: 1.4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _selectedImage == null
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 72,
                                        color: secondary,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Foto belum dipilih',
                                        style: TextStyle(
                                          color: text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Image.file(_selectedImage!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accent, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hasil Klasifikasi Rempah',
                              style: TextStyle(
                                color: text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _predictionLabel,
                              style: const TextStyle(
                                color: text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tingkat keyakinan: ${(_confidence * 100).toStringAsFixed(2)}%',
                              style: const TextStyle(
                                color: text,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: primary,
                                  strokeWidth: 2.2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Sedang menganalisis foto...',
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: !_isModelReady || _isLoading
                                  ? null
                                  : () => _pickAndClassify(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text('Buka Kamera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: !_isModelReady || _isLoading
                                  ? null
                                  : () => _pickAndClassify(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded),
                              label: const Text('Ambil dari Galeri'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
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
}
