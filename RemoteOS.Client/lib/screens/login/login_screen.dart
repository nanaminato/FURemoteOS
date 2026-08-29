import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependency_injection.dart';
import '../../core/auth/auth_service.dart';
import '../../core/localization/language_catalog.dart';
import '../../core/runtime/desktop_runtime.dart';
import '../../core/theme/theme_service.dart';

/// Remote Desktop Connection-style sign-in surface.
///
/// This page intentionally has no scrolling region. The desktop window has a
/// minimum height that accommodates the expanded form, matching the reference
/// client and avoiding viewport-dependent clipping and scrollbar artefacts.
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
    final notifier = ref.read(authProvider.notifier);
    final credentials = await notifier.loadSavedCredentials();
    final profiles = await notifier.loadSavedProfiles();
    final savedProfile = profiles
        .where((profile) =>
            profile.serverUrl == credentials.server &&
            profile.username == credentials.username)
        .firstOrNull;
    final password = savedProfile?.hasSavedPassword == true
        ? await notifier.loadSavedPassword(
            serverUrl: credentials.server, username: credentials.username)
        : null;
    if (!mounted) return;
    setState(() {
      _serverController.text = credentials.server;
      _usernameController.text = credentials.username;
      _passwordController.text = password ?? '';
      _rememberPassword = password != null;
      _showOptions = !_rememberPassword;
    });
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final log = _optionalRuntimeLog();
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    unawaited(log?.info(
      '[login] connect requested server=$server username=$username '
      'rememberServer=$_rememberServer rememberPassword=$_rememberPassword',
    ));
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final stopwatch = Stopwatch()..start();
    final success = await ref.read(authProvider.notifier).login(
          serverUrl: server,
          username: username,
          password: _passwordController.text,
          rememberServer: _rememberServer,
          rememberPassword: _rememberPassword,
        );
    stopwatch.stop();

    if (!mounted) {
      unawaited(log?.info('[login] widget unmounted before login response'));
      return;
    }
    setState(() => _isLoading = false);
    final authState = ref.read(authProvider);
    unawaited(log?.info(
      '[login] finished in ${stopwatch.elapsedMilliseconds}ms success=$success '
      'authState=${authState.state} authenticated=${authState.isAuthenticated} '
      'hasError=${authState.errorMessage != null}',
    ));
    if (success && authState.isAuthenticated) {
      unawaited(log?.info('[login] navigating to /desktop'));
      context.go('/desktop');
    } else if (authState.errorMessage != null) {
      setState(() => _errorMessage = authState.errorMessage);
    }
  }

  RuntimeLog? _optionalRuntimeLog() {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final authState = ref.watch(authProvider);
    final languages = ref.watch(languageCatalogProvider).languages;

    return Scaffold(
      backgroundColor: palette.shellBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.borderDefault),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: palette.cardShadow,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildProductBanner(palette),
                      Divider(height: 1, color: palette.borderDefault),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 20, 32, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'login.connection_instructions'.tr(),
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 3, bottom: 12),
                              child: Text(
                                'login.credentials_instructions'.tr(),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            _buildLanguageRow(palette, languages),
                            const SizedBox(height: 10),
                            _buildFieldRow(
                              palette,
                              'login.computer'.tr(),
                              _buildServerField(palette),
                            ),
                            const SizedBox(height: 12),
                            _buildFieldRow(
                              palette,
                              'login.username'.tr(),
                              _buildUsernameField(palette),
                            ),
                            if (_showOptions) ...[
                              const SizedBox(height: 12),
                              _buildFieldRow(
                                palette,
                                'login.password'.tr(),
                                _buildPasswordField(palette),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.only(left: 108, top: 8),
                              child: _buildOptionsToggle(palette),
                            ),
                            if (_showOptions) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 108, top: 8),
                                child: _buildCheckbox(
                                  palette: palette,
                                  value: _rememberServer,
                                  onChanged: (value) => setState(
                                    () => _rememberServer = value ?? true,
                                  ),
                                  label: 'login.remember_server'.tr(),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 108, top: 4),
                                child: _buildCheckbox(
                                  palette: palette,
                                  value: _rememberPassword,
                                  onChanged: _rememberServer
                                      ? (value) => setState(
                                            () => _rememberPassword =
                                                value ?? false,
                                          )
                                      : null,
                                  label: 'login.remember_password'.tr(),
                                ),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.only(left: 108, top: 9),
                              child: Text(
                                'login.identity_notice'.tr(),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            _buildConnectionSettingsNotice(palette),
                            if (authState.state == AuthState.authenticating)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  color: palette.accent,
                                  backgroundColor: palette.surfaceSunken,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildFooter(palette, authState),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductBanner(ThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 21),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.desktop_windows_outlined,
              size: 31,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RemoteOS',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Text(
                'login.title'.tr(),
                style: TextStyle(color: palette.textPrimary, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow(
    ThemePalette palette,
    List<LanguageOption> languages,
  ) {
    final current = context.locale.toLanguageTag();
    final selected = languages.any((language) =>
            language.locale.toLanguageTag().toLowerCase() ==
            current.toLowerCase())
        ? context.locale
        : languages.first.locale;
    return _buildFieldRow(
      palette,
      'login.display_language'.tr(),
      DropdownButtonFormField<Locale>(
        value: selected,
        isExpanded: true,
        decoration: _inputDecoration(palette),
        dropdownColor: palette.surface,
        items: [
          for (final language in languages)
            DropdownMenuItem(
              value: language.locale,
              child: Text(language.displayName),
            ),
        ],
        onChanged: (locale) {
          if (locale != null) context.setLocale(locale);
        },
      ),
    );
  }

  Widget _buildFieldRow(ThemePalette palette, String label, Widget field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: field),
      ],
    );
  }

  InputDecoration _inputDecoration(ThemePalette palette, {String? hintText}) =>
      InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: palette.textTertiary),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );

  Widget _buildServerField(ThemePalette palette) => TextFormField(
        controller: _serverController,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: _inputDecoration(palette, hintText: 'http://host:port'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'login.error.invalid_server'.tr();
          }
          return ref.read(authProvider.notifier).isValidServerUrl(value.trim())
              ? null
              : 'login.error.invalid_server'.tr();
        },
        onFieldSubmitted: (_) => _connect(),
      );

  Widget _buildUsernameField(ThemePalette palette) => TextFormField(
        controller: _usernameController,
        readOnly: !_showOptions,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: _inputDecoration(
          palette,
          hintText: 'login.username_placeholder'.tr(),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'login.username_placeholder'.tr()
            : null,
        onFieldSubmitted: (_) => _connect(),
      );

  Widget _buildPasswordField(ThemePalette palette) => TextFormField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: _inputDecoration(
          palette,
          hintText: 'login.password_placeholder'.tr(),
        ).copyWith(
          suffixIcon: TextButton(
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              (_isPasswordVisible
                      ? 'login.password_hide'
                      : 'login.password_show')
                  .tr(),
              style: TextStyle(fontSize: 12, color: palette.accent),
            ),
          ),
        ),
        validator: (value) => value == null || value.isEmpty
            ? 'login.password_placeholder'.tr()
            : null,
        onFieldSubmitted: (_) => _connect(),
      );

  Widget _buildOptionsToggle(ThemePalette palette) => TextButton(
        onPressed: () => setState(() => _showOptions = !_showOptions),
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(vertical: 2),
          foregroundColor: palette.accent,
        ),
        child: Text(
          (_showOptions ? 'login.options_hide' : 'login.options_show').tr(),
          style: const TextStyle(fontSize: 12),
        ),
      );

  Widget _buildCheckbox({
    required ThemePalette palette,
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String label,
  }) =>
      InkWell(
        onTap: onChanged == null ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(3),
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
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: onChanged == null
                      ? palette.textTertiary
                      : palette.textPrimary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildConnectionSettingsNotice(ThemePalette palette) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          border: Border.all(color: palette.borderDefault),
          borderRadius: BorderRadius.circular(2),
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
            const SizedBox(height: 3),
            Text(
              'login.connection_settings_description'.tr(),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      );

  Widget _buildFooter(ThemePalette palette, AuthSessionState authState) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(32, 11, 32, 14),
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          border: Border(top: BorderSide(color: palette.borderDefault)),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                      color: palette.danger, fontSize: 12, height: 1.3),
                ),
              )
            else if (authState.state == AuthState.authenticating)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'login.status.connecting'.tr(),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'login.client_name'.tr(),
                    style:
                        TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
                ),
                FilledButton(
                  onPressed:
                      _isLoading || authState.state == AuthState.authenticating
                          ? null
                          : _connect,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(92, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: Text('common.connect'.tr()),
                ),
              ],
            ),
          ],
        ),
      );
}
