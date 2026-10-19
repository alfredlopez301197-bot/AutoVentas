
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _domainController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _domainFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _autovalidate = false;
  String? _errorText;

  bool _showBiometricOption = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final domain = await AuthService.currentDomain();

    if (domain != null && mounted) {
      _domainController.text = domain;
    }

    final hasSession = await AuthService.hasStoredSession();
    if (!hasSession) return;

    final biometricEnabled = await AuthService.isBiometricEnabled();
    if (!biometricEnabled) return;

    bool supported = false;

    try {
      final auth = LocalAuthentication();
      supported =
          (await auth.canCheckBiometrics) ||
          (await auth.isDeviceSupported());
    } catch (_) {
      supported = false;
    }

    if (!mounted) return;
    setState(() => _showBiometricOption = supported);
  }

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _biometricBusy = true;
      _errorText = null;
    });

    try {
      final auth = LocalAuthentication();

      final confirmed = await auth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a tu cuenta',
        persistAcrossBackgrounding: true,
      );

      if (!confirmed) {
        if (!mounted) return;
        setState(() => _biometricBusy = false);
        return;
      }

      try {
        await AuthService.refreshSession();
      } on AuthException catch (e) {
        if (e.serverRejected) rethrow;
      }

      unawaited(PushNotificationService.registerForCurrentUser());

      if (!mounted) return;
      context.go('/welcome');
    } on AuthException catch (e) {
      if (e.serverRejected) {
        await AuthService.clearSession();
        if (mounted) {
          setState(() => _showBiometricOption = false);
        }
      }

      if (!mounted) return;

      if (e.accessRestricted) {
        context.go('/access-restricted', extra: e.message);
        return;
      }

      setState(() {
        _biometricBusy = false;
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _biometricBusy = false;
        _errorText =
            'No se pudo confirmar tu huella. Inténtalo de nuevo '
            'o inicia sesión manualmente.';
      });
    }
  }

  @override
  void dispose() {
    _domainController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    _domainFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();

    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _autovalidate = true);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await AuthService.login(
        domain: _domainController.text,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      unawaited(PushNotificationService.registerForCurrentUser());

      if (!mounted) return;
      context.go('/welcome');
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.accessRestricted) {
        setState(() => _isLoading = false);
        context.go('/access-restricted', extra: e.message);
        return;
      }

      setState(() {
        _isLoading = false;
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorText =
            'Ocurrió un error inesperado. Inténtalo de nuevo más tarde.';
      });
    }
  }

  void _handleForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Esta función todavía no está disponible. '
          'Contacta con el administrador de tu empresa.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Conservamos el logotipo original temporalmente.
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.black,
                            Color(0xFF2A2A2A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: AppLogo(
                          size: 38,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Center(
                    child: Text(
                      'PANDA',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: AppColors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Introduce los datos de tu empresa para continuar',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.midGray,
                    ),
                  ),

                  const SizedBox(height: 28),

                  if (_showBiometricOption) ...[
                    _buildBiometricOption(),
                    const SizedBox(height: 20),
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'O inicia sesión manualmente',
                            style: TextStyle(
                              color: AppColors.midGray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 4),

                  TextFormField(
                    controller: _domainController,
                    focusNode: _domainFocus,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.url],
                    onFieldSubmitted: (_) =>
                        _usernameFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Dominio de la empresa',
                      hintText: 'Ej.: empresa.tudominio.com',
                      prefixIcon: Icon(
                        Icons.dns_rounded,
                        color: AppColors.midGray,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                        ? 'Introduce el dominio de la empresa'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.username],
                    onFieldSubmitted: (_) =>
                        _passwordFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.midGray,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                        ? 'Introduce tu nombre de usuario'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.midGray,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.midGray,
                        ),
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty)
                        ? 'Introduce tu contraseña'
                        : null,
                  ),

                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorText!,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: const Text('¿Olvidaste tu contraseña?'),
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

  Widget _buildBiometricOption() {
    return Material(
      color: AppColors.lightGray,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: _biometricBusy ? null : _handleBiometricLogin,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: _biometricBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.white,
                      ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acceso con huella',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Usa tu huella para entrar rápidamente',
                      style: TextStyle(
                        color: AppColors.midGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.midGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
