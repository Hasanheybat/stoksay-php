import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/bildirim.dart';
import '../providers/isletme_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _sifreGoster = false;
  bool _yukleniyor = false;
  bool _otomatikKontrol = true;

  static const _primary = Color(0xFF6C53F5);
  static const _gradStart = Color(0xFF1E1B4B);
  static const _gradEnd = Color(0xFF4C1D95);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _oturumKontrol());
  }

  Future<void> _oturumKontrol() async {
    final auth = ref.read(authProvider.notifier);
    await auth.oturumKontrol();
    auth.initLifecycleObserver();
    final state = ref.read(authProvider);
    if (state.kullanici != null && mounted) {
      await ref.read(isletmeProvider.notifier).yukle();
      if (mounted) context.go('/');
    }
    if (mounted) setState(() => _otomatikKontrol = false);
  }

  Future<void> _girisYap() async {
    final email = _emailController.text.trim();
    final sifre = _sifreController.text.trim();
    if (email.isEmpty || sifre.isEmpty) {
      _snackBar('Email ve sifre zorunludur.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _snackBar('Gecerli bir email adresi giriniz.');
      return;
    }
    if (sifre.length < 8) {
      _snackBar('Sifre en az 8 karakter olmalidir.');
      return;
    }

    setState(() => _yukleniyor = true);
    final basarili = await ref.read(authProvider.notifier).login(email, sifre);

    if (basarili && mounted) {
      await ref.read(isletmeProvider.notifier).yukle();
      if (mounted) context.go('/');
    } else if (mounted) {
      final hata = ref.read(authProvider).hata;
      _snackBar(hata ?? 'Email veya sifre hatali.');
      setState(() => _yukleniyor = false);
    }
  }

  void _snackBar(String msg) {
    if (!mounted) return;
    showBildirim(context, msg, basarili: false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_otomatikKontrol) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradStart, _gradEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.5),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('StokSay',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('Depo Sayim Sistemi',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1)),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 60, offset: const Offset(0, 20)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hos geldiniz',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        const Text('Hesabiniza giris yapin',
                            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                        const SizedBox(height: 28),

                        _label('E-POSTA'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('kullanici@ornek.com'),
                        ),
                        const SizedBox(height: 16),

                        _label('SIFRE'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _sifreController,
                          obscureText: !_sifreGoster,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _girisYap(),
                          decoration: _inputDecoration('--------').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _sifreGoster ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _sifreGoster = !_sifreGoster),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ElevatedButton(
                              onPressed: _yukleniyor ? null : _girisYap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _yukleniyor
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Giris Yap',
                                            style: TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 12),
                  Text('StokSay v2.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 1));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF818CF8)),
      ),
    );
  }
}
