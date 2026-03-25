import 'dart:async';
import 'package:flutter/material.dart';

/// Bildirim tipleri: basarili (yeşil), hata (kırmızı), bilgi (mor)
enum BildirimTip { basarili, hata, bilgi }

OverlayEntry? _aktifBildirim;
Timer? _aktifTimer;

/// Sağ üstten kayarak çıkan ve kaybolan bildirim
void showBildirim(
  BuildContext context,
  String mesaj, {
  bool basarili = true,
  BildirimTip? tip,
  int sure = 2,
}) {
  // Önceki bildirimi kaldır
  _aktifBildirim?.remove();
  _aktifBildirim = null;
  _aktifTimer?.cancel();

  final overlay = Overlay.of(context);

  // Tip belirleme: tip parametresi varsa onu kullan, yoksa basarili/hata
  final bildirimTip = tip ?? (basarili ? BildirimTip.basarili : BildirimTip.hata);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _BildirimWidget(
      mesaj: mesaj,
      tip: bildirimTip,
      sure: sure,
      onKapat: () {
        entry.remove();
        if (_aktifBildirim == entry) _aktifBildirim = null;
      },
    ),
  );

  _aktifBildirim = entry;
  overlay.insert(entry);

  _aktifTimer = Timer(Duration(seconds: sure + 1), () {
    if (_aktifBildirim == entry) {
      entry.remove();
      _aktifBildirim = null;
    }
  });
}

class _BildirimWidget extends StatefulWidget {
  final String mesaj;
  final BildirimTip tip;
  final int sure;
  final VoidCallback onKapat;

  const _BildirimWidget({
    required this.mesaj,
    required this.tip,
    required this.sure,
    required this.onKapat,
  });

  @override
  State<_BildirimWidget> createState() => _BildirimWidgetState();
}

class _BildirimWidgetState extends State<_BildirimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // sağdan gir
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Süre sonunda çık
    Future.delayed(Duration(seconds: widget.sure), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onKapat();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 12;

    Color renk1, renk2;
    IconData ikon;

    switch (widget.tip) {
      case BildirimTip.basarili:
        renk1 = const Color(0xFF10B981);
        renk2 = const Color(0xFF059669);
        ikon = Icons.check_circle;
        break;
      case BildirimTip.hata:
        renk1 = const Color(0xFFEF4444);
        renk2 = const Color(0xFFDC2626);
        ikon = Icons.error;
        break;
      case BildirimTip.bilgi:
        renk1 = const Color(0xFF6C53F5);
        renk2 = const Color(0xFF8B5CF6);
        ikon = Icons.info;
        break;
    }

    return Positioned(
      top: top,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                  _controller.reverse().then((_) {
                    if (mounted) widget.onKapat();
                  });
                }
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [renk1, renk2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: renk1.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ikon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.mesaj,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
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
    );
  }
}
