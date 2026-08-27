import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_service.dart';
import '../../core/auth/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // A remembered password means the compact connection form is sufficient on
  // the next launch.  Keep the detailed fields available, but do not let the
  // expanded state dictate the window's height.
  bool _showOptions = true;
  bool _isPasswordVisible = false;
  bool _rememberServer = true;
  bool _rememberPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await ref.read(authProvider.notifier).loadSavedCredentials();
    final profiles = await ref.read(authProvider.notifier).loadSavedProfiles();
    if (mounted) {
      setState(() {
        _serverController.text = creds.server;
        _usernameController.text = creds.username;
        _rememberPassword = profiles.any((profile) =>
            profile.serverUrl == creds.server &&
            profile.encryptedPassword != null);
        _showOptions = !_rememberPassword;
      });
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.login(
      serverUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rememberServer: _rememberServer,
      rememberPassword: _rememberPassword,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final authState = ref.read(authProvider);
    if (success && authState.isAuthenticated) {
      context.go('/desktop');
    } else if (authState.errorMessage != null) {
      setState(() => _errorMessage = authState.errorMessage);
    }
  }

  void _changeLanguage(Locale? locale) {
    if (locale != null) {
      context.setLocale(locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: palette.shellBackground,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final horizontalMargin = viewport.maxWidth < 640 ? 16.0 : 32.0;
          final cardWidth = (viewport.maxWidth - horizontalMargin * 2)
              .clamp(280.0, 560.0)
              .toDouble();
          // The header and footer stay visible.  Only the form scrolls, so
          // revealing connection options cannot overflow a short window.
          final cardHeight =
              (viewport.maxHeight - 32).clamp(360.0, 700.0).toDouble();
          return Center(
            child: Container(
              width: cardWidth,
              height: cardHeight,
              margin: EdgeInsets.symmetric(
                  horizontal: horizontalMargin, vertical: 16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.borderDefault),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(palette),
                  Expanded(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLanguageSelector(palette),
                              const SizedBox(height: 20),
                              Text(
                                'login.connection_instructions'.tr(),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildComputerField(palette),
                              const SizedBox(height: 16),
                              Text(
                                'login.credentials_instructions'.tr(),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildUsernameField(palette),
                              const SizedBox(height: 16),
                              _buildPasswordField(palette),
                              const SizedBox(height: 8),
                              if (_errorMessage != null)
                                _buildErrorMessage(palette),
                              if (authState.state == AuthState.authenticating)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: palette.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'login.status.connecting'.tr(),
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _buildOptionsToggle(palette),
                              if (_showOptions) _buildOptionsPanel(palette),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () {},
                                    child:
                                        Text('common.settings_ellipsis'.tr()),
                                  ),
                                  FilledButton(
                                    onPressed: _isLoading ||
                                            authState.state ==
                                                AuthState.authenticating
                                        ? null
                                        : _connect,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(120, 40),
                                    ),
                                    child: Text('common.connect'.tr()),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildFooter(palette),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemePalette palette) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withOpacity(0.85),
            palette.accent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.desktop_windows_rounded,
            color: palette.textOnAccent,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'login.title'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textOnAccent,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'login.client_name'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textOnAccent.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(ThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'login.display_language'.tr(),
          style: TextStyle(color: palette.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 220,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Locale>(
              value: context.locale,
              isExpanded: true,
              dropdownColor: palette.surface,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: palette.textSecondary),
              items: context.supportedLocales.map((locale) {
                final nameKey =
                    'language.${locale.toLanguageTag().replaceAll('-', '_')}';
                return DropdownMenuItem<Locale>(
                  value: locale,
                  child: Text(
                    nameKey.tr(),
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: _changeLanguage,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComputerField(ThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'login.computer'.tr(),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _serverController,
          style: TextStyle(color: palette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'http://localhost:5090',
            hintStyle: TextStyle(color: palette.textTertiary),
            prefixIcon: Icon(Icons.computer_outlined,
                color: palette.textSecondary, size: 18),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a server address';
            }
            final valid =
                ref.read(authProvider.notifier).isValidServerUrl(value.trim());
            if (!valid) return 'login.error.invalid_server'.tr();
            return null;
          },
          onFieldSubmitted: (_) => _connect(),
        ),
      ],
    );
  }

  Widget _buildUsernameField(ThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'login.username'.tr(),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _usernameController,
          style: TextStyle(color: palette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'login.username_placeholder'.tr(),
            hintStyle: TextStyle(color: palette.textTertiary),
            prefixIcon: Icon(Icons.person_outline,
                color: palette.textSecondary, size: 18),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            return null;
          },
          onFieldSubmitted: (_) => _connect(),
        ),
      ],
    );
  }

  Widget _buildPasswordField(ThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'login.password'.tr(),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: TextStyle(color: palette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'login.password_placeholder'.tr(),
            hintStyle: TextStyle(color: palette.textTertiary),
            prefixIcon: Icon(Icons.lock_outline,
                color: palette.textSecondary, size: 18),
            suffixIcon: TextButton(
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
              style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(
                _isPasswordVisible
                    ? 'login.password_hide'.tr()
                    : 'login.password_show'.tr(),
                style: TextStyle(fontSize: 12, color: palette.accent),
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            return null;
          },
          onFieldSubmitted: (_) => _connect(),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.dangerMuted,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.danger.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: palette.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style:
                    TextStyle(color: palette.danger, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsToggle(ThemePalette palette) {
    return TextButton(
      onPressed: () => setState(() => _showOptions = !_showOptions),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(vertical: 4),
        foregroundColor: palette.accent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showOptions
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18,
          ),
          const SizedBox(width: 2),
          Text(
            _showOptions
                ? 'login.options_hide'.tr()
                : 'login.options_show'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsPanel(ThemePalette palette) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'login.connection_settings'.tr(),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'login.connection_settings_description'.tr(),
            style: TextStyle(
                color: palette.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildCheckboxRow(
            palette: palette,
            value: _rememberServer,
            onChanged: (v) => setState(() => _rememberServer = v ?? true),
            label: 'login.remember_server'.tr(),
          ),
          const SizedBox(height: 8),
          _buildCheckboxRow(
            palette: palette,
            value: _rememberPassword,
            onChanged: (v) => setState(() => _rememberPassword = v ?? false),
            label: 'login.remember_password'.tr(),
          ),
          const SizedBox(height: 12),
          Text(
            'login.identity_notice'.tr(),
            style: TextStyle(
                color: palette.textTertiary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow({
    required ThemePalette palette,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: palette.textPrimary, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: palette.info, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'RemoteOS v1.0.0 — Flutter Edition',
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
