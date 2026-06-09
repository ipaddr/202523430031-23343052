import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/ai_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/services/auth_service.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

// Model sederhana untuk satu pesan di chat
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isQuotaError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isQuotaError = false,
  });
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final AiService _aiService = AiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Simpan maksimal 10 pesan di UI
  final List<_ChatMessage> _messages = [];
  static const int _maxMessages = 10;

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = 5;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          _cooldownTimer?.cancel();
        }
      });
    });
  }

  // Kirim pesan ke Gemini
  Future<void> _sendMessage() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _isLoading || _cooldownSeconds > 0) return;

    _inputController.clear();

    setState(() {
      _addMessage(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    final String response = await _aiService.sendMessage(text);

    if (!mounted) return;

    // Deteksi jika API gagal/error berdasarkan mapping user-friendly di AiService
    final bool isQuotaError = response == 'AI sedang sibuk. Silakan coba lagi beberapa saat.' ||
        response == 'Kuota AI sedang penuh. Coba lagi nanti.';

    final bool isError = isQuotaError ||
        response == 'Koneksi internet bermasalah.' ||
        response == 'Permintaan terlalu lama. Coba lagi.' ||
        response == 'Terjadi kesalahan. Silakan coba kembali.';

    final String displayText = isQuotaError
        ? 'AI sedang sibuk. Coba lagi dalam beberapa detik.'
        : response;

    if (isQuotaError) {
      _startCooldown();
    }

    setState(() {
      _addMessage(_ChatMessage(
        text: displayText,
        isUser: false,
        isError: isError && !isQuotaError,
        isQuotaError: isQuotaError,
      ));
      _isLoading = false;
    });

    _scrollToBottom();
  }

  // Tambah pesan dan batasi hingga 10 pesan
  void _addMessage(_ChatMessage message) {
    _messages.add(message);
    if (_messages.length > _maxMessages) {
      _messages.removeAt(0);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return const SizedBox.shrink();

    final FirestoreService firestoreService = FirestoreService();

    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getUserStream(currentUser.uid),
      builder: (context, snapshot) {
        String? dbPhotoUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          dbPhotoUrl = data['foto'] as String?;
        }

        final String photoUrl = dbPhotoUrl ?? '';

        final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final double bottomInset = MediaQuery.of(context).padding.bottom;
        final double bottomPadding = keyboardHeight > 0
            ? (keyboardHeight - 84 - bottomInset).clamp(0.0, double.infinity)
            : 0.0;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isLoading) {
                              return _buildLoadingBubble();
                            }
                            return _buildMessageBubble(_messages[index], userPhotoUrl: photoUrl);
                          },
                        ),
                      ),
              ),

              _buildInputArea(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: Gradients.kAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Halo, Gamers!',
              style: AppTextStyle.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tanya apa saja seputar gaming.\nJawaban singkat dan langsung ke inti.',
              style: AppTextStyle.body3.copyWith(
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            _buildExampleChip('Game apa yang cocok untuk 4 orang?'),
            const SizedBox(height: 8),
            _buildExampleChip('Rekomendasi game FPS terbaik?'),
            const SizedBox(height: 8),
            _buildExampleChip('Berapa jam ideal bermain game per hari?'),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String question) {
    return GestureDetector(
      onTap: () {
        _inputController.text = question;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.accentCyan,
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: AppTextStyle.body3.copyWith(
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, {String? userPhotoUrl}) {
    if (message.isQuotaError) {
      return _buildAiStatusCard(message.text);
    }
    if (message.isError) {
      return _buildErrorCard(message.text);
    }

    final bool isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: Gradients.kAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: isUser
                    ? BoxDecoration(
                        gradient: Gradients.kAccent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: AppColors.secondaryDark.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                child: Text(
                  message.text,
                  softWrap: true,
                  style: AppTextStyle.body2.copyWith(
                    color: Colors.white,
                    height: 1.5,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CustomUserAvatar(
              photoUrl: userPhotoUrl,
              size: 36,
              hasBorder: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiStatusCard(String errorMessage) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.accentCyan,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                errorMessage,
                style: AppTextStyle.body2.copyWith(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String errorMessage) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.errorRed.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.errorRed,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                errorMessage,
                style: AppTextStyle.body2.copyWith(
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: Gradients.kAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.secondaryDark.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            child: const _TypingIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, keyboardHeight > 0 ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDarkNavy,
        border: Border(
          top: BorderSide(
            color: AppColors.accentCyan.withValues(alpha: 0.12),
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: const Color(0xFF334155).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _inputController,
                style: AppTextStyle.body2.copyWith(color: AppColors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: 'Tanyakan sesuatu...',
                  hintStyle: AppTextStyle.body3.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          GestureDetector(
            onTap: (_isLoading || _cooldownSeconds > 0) ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: (_isLoading || _cooldownSeconds > 0) ? null : Gradients.kAccent,
                color: (_isLoading || _cooldownSeconds > 0) ? const Color(0xFF1E293B) : null,
                borderRadius: BorderRadius.circular(22),
                border: _cooldownSeconds > 0
                    ? Border.all(color: AppColors.errorRed.withValues(alpha: 0.5), width: 1.5)
                    : null,
                boxShadow: (_isLoading || _cooldownSeconds > 0)
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.accentCyan,
                        ),
                      )
                    : _cooldownSeconds > 0
                        ? Text(
                            '${_cooldownSeconds}s',
                            style: AppTextStyle.body2.copyWith(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double progress = (_controller.value + index * 0.25) % 1.0;
            final double opacity = (progress < 0.5)
                ? progress * 2
                : 1.0 - (progress - 0.5) * 2;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: 0.3 + opacity * 0.7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accentCyan,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

