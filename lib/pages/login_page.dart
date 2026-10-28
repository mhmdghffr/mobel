
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _obscurePassword = true;

  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color backgroundColor = Color(0xFFFFF8F0);

  bool get _isBusy => _isLoading || _isBiometricLoading;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Memeriksa dukungan biometrik perangkat.
  Future<bool> _deviceSupportsBiometrics() async {
    try {
      final bool supported =
          await _localAuth.isDeviceSupported();
      final bool canCheck =
          await _localAuth.canCheckBiometrics;
      final List<BiometricType> biometrics =
          await _localAuth.getAvailableBiometrics();

      return supported && canCheck && biometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Pemeriksaan biometrik gagal: $e');
      return false;
    }
  }

  // Autentikasi biometrik.
  // stickyAuth dihapus karena tidak didukung versi local_auth ini.
  Future<bool> _authenticateBiometric({
    required String reason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (e) {
      debugPrint('Autentikasi biometrik gagal: $e');
      return false;
    }
  }

  // Login menggunakan username dan password.
  Future<void> _login() async {
    if (_isBusy) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final AppUser? user = await _authService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (user == null) {
        _showMessage(
          'Username atau password salah, atau akun tidak aktif.',
        );
        return;
      }

      // Simpan sesi setelah login server berhasil.
      await SessionManager.saveSession(user);

      if (!mounted) return;

      final bool supportsBiometrics =
          await _deviceSupportsBiometrics();

      if (!mounted) return;

      if (supportsBiometrics) {
        await _offerBiometricLogin(user);
      }

      if (!mounted) return;

      _openHome(user);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Terjadi kesalahan saat login: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Menawarkan aktivasi login sidik jari.
  Future<void> _offerBiometricLogin(AppUser user) async {
    final bool? enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Aktifkan login sidik jari?'),
          content: const Text(
            'Gunakan sidik jari untuk login lebih cepat '
            'di perangkat ini pada kesempatan berikutnya.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Nanti saja'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
              ),
              child: const Text('Aktifkan'),
            ),
          ],
        );
      },
    );

    if (!mounted || enable != true) return;

    final bool authenticated = await _authenticateBiometric(
      reason:
          'Verifikasi identitas untuk mengaktifkan login sidik jari',
    );

    if (!mounted) return;

    if (!authenticated) {
      _showMessage(
        'Verifikasi gagal. Login sidik jari belum diaktifkan.',
      );
      return;
    }

    try {
      await SessionManager.enableBiometricLogin(user);

      if (!mounted) return;

      _showMessage('Login sidik jari berhasil diaktifkan.');
    } catch (e) {
      _showMessage(
        'Gagal menyimpan pengaturan biometrik: $e',
      );
    }
  }

  // Login biometrik dengan validasi token ke server.
  Future<void> _loginWithBiometrics() async {
    if (_isBusy) return;

    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final bool enabled =
          await SessionManager.isBiometricLoginEnabled();

      if (!mounted) return;

      if (!enabled) {
        _showMessage(
          'Login sidik jari belum diaktifkan. '
          'Silakan login menggunakan password terlebih dahulu.',
        );
        return;
      }

      final bool supported =
          await _deviceSupportsBiometrics();

      if (!mounted) return;

      if (!supported) {
        _showMessage(
          'Biometrik tidak tersedia. Periksa pengaturan perangkat.',
        );
        return;
      }

      final String? token =
          await SessionManager.getSecureToken();

      if (!mounted) return;

      if (token == null || token.isEmpty) {
        await SessionManager.clearSession();

        if (!mounted) return;

        _showMessage(
          'Sesi login tidak ditemukan. Silakan login kembali.',
        );
        return;
      }

      final bool authenticated = await _authenticateBiometric(
        reason: 'Letakkan jari untuk masuk ke Cafe Shop',
      );

      if (!mounted) return;

      if (!authenticated) {
        _showMessage(
          'Verifikasi sidik jari dibatalkan atau gagal.',
        );
        return;
      }

      // Token tetap harus divalidasi oleh server.
      final AppUser? user =
          await _authService.validateSession(token);

      if (!mounted) return;

      if (user == null) {
        await SessionManager.clearSession();

        if (!mounted) return;

        _showMessage(
          'Sesi tidak valid atau server tidak dapat dihubungi. '
          'Silakan login menggunakan password.',
        );
        return;
      }

      await SessionManager.saveSession(user);

      if (!mounted) return;

      _openHome(user);
    } catch (e) {
      _showMessage('Login sidik jari gagal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  // Membuka halaman utama.
  void _openHome(AppUser user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => HomePage(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo aplikasi.
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryBrown.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_cafe,
                        size: 66,
                        color: primaryBrown,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Cafe Shop',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Silakan masuk ke akun Anda',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Username.
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_isBusy,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Masukkan username',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: primaryBrown,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFD7CCC8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: primaryBrown,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Username wajib diisi';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Password.
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isBusy,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isBusy) _login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Masukkan password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: primaryBrown,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Tampilkan password'
                              : 'Sembunyikan password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: _isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword =
                                        !_obscurePassword;
                                  });
                                },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFD7CCC8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: primaryBrown,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password wajib diisi';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 26),

                    // Tombol login biasa.
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isBusy ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBrown,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              primaryBrown.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'MASUK',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tombol login sidik jari.
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy
                            ? null
                            : _loginWithBiometrics,
                        icon: _isBiometricLoading
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.fingerprint,
                                size: 30,
                              ),
                        label: const Text(
                          'MASUK DENGAN SIDIK JARI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBrown,
                          side: const BorderSide(
                            color: primaryBrown,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Cafe Management System',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
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
