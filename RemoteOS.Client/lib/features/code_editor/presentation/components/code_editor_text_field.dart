import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/bash.dart' as bash;
import 'package:highlight/languages/cpp.dart' as cpp;
import 'package:highlight/languages/cs.dart' as csharp;
import 'package:highlight/languages/css.dart' as css;
import 'package:highlight/languages/dart.dart' as dart;
import 'package:highlight/languages/dockerfile.dart' as dockerfile;
import 'package:highlight/languages/go.dart' as go;
import 'package:highlight/languages/ini.dart' as ini;
import 'package:highlight/languages/java.dart' as java;
import 'package:highlight/languages/javascript.dart' as javascript;
import 'package:highlight/languages/json.dart' as json;
import 'package:highlight/languages/kotlin.dart' as kotlin;
import 'package:highlight/languages/markdown.dart' as markdown;
import 'package:highlight/languages/php.dart' as php;
import 'package:highlight/languages/python.dart' as python;
import 'package:highlight/languages/ruby.dart' as ruby;
import 'package:highlight/languages/rust.dart' as rust;
import 'package:highlight/languages/sql.dart' as sql;
import 'package:highlight/languages/swift.dart' as swift;
import 'package:highlight/languages/typescript.dart' as typescript;
import 'package:highlight/languages/xml.dart' as xml;
import 'package:highlight/languages/yaml.dart' as yaml;

import '../../../../core/theme/theme_service.dart';
import '../../application/code_editor_view_model.dart';
import '../../domain/code_editor_ui_state.dart';

/// Flutter-specific editor resources live here, while remote document state
/// remains in the ViewModel. The component owns its controller and selects a
/// highlighter from the active document's remote filename.
class CodeEditorTextField extends StatefulWidget {
  const CodeEditorTextField({
    super.key,
    required this.vm,
    required this.state,
  });

  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  State<CodeEditorTextField> createState() => _CodeEditorTextFieldState();
}

class _CodeEditorTextFieldState extends State<CodeEditorTextField> {
  late final CodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.state.activeDocument?.text,
      language: _languageForPath(widget.state.activeDocument?.path),
    );
  }

  @override
  void didUpdateWidget(covariant CodeEditorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final document = widget.state.activeDocument;
    final text = document?.text ?? '';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(text: text);
    }
    final language = _languageForPath(document?.path);
    if (_controller.language != language) _controller.language = language;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textStyle = TextStyle(
      color: palette.textPrimary,
      fontFamily: 'monospace',
      fontSize: widget.state.fontSize,
      height: 1.45,
    );
    return CodeTheme(
      data: CodeThemeData(styles: _syntaxStyles(palette)),
      child: CodeField(
        controller: _controller,
        expands: true,
        maxLines: null,
        minLines: null,
        wrap: widget.state.wordWrap,
        background: palette.surface,
        cursorColor: palette.textPrimary,
        textStyle: textStyle,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: palette.textPrimary,
          selectionColor: palette.selectionBackground,
          selectionHandleColor: palette.accent,
        ),
        gutterStyle: GutterStyle(
          background: palette.surfaceRaised,
          textStyle: TextStyle(color: palette.textTertiary),
          showErrors: false,
          showFoldingHandles: false,
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        onChanged: widget.vm.updateActiveDocument,
      ),
    );
  }
}

Map<String, TextStyle> _syntaxStyles(ThemePalette palette) => {
      'root': TextStyle(color: palette.textPrimary),
      'comment':
          TextStyle(color: palette.textTertiary, fontStyle: FontStyle.italic),
      'quote':
          TextStyle(color: palette.textTertiary, fontStyle: FontStyle.italic),
      'keyword': TextStyle(color: palette.accent),
      'literal': TextStyle(color: palette.info),
      'string': TextStyle(color: palette.success),
      'number': TextStyle(color: palette.warning),
      'type': TextStyle(color: palette.warning),
      'built_in': TextStyle(color: palette.info),
      'title': TextStyle(color: palette.accent),
      'function': TextStyle(color: palette.accent),
      'attr': TextStyle(color: palette.accent),
      'meta': TextStyle(color: palette.textSecondary),
      'params': TextStyle(color: palette.textPrimary),
    };

Mode? _languageForPath(String? path) {
  final fileName = path?.replaceAll('\\', '/').split('/').last.toLowerCase();
  final extension = fileName?.split('.').last;
  if (fileName == 'dockerfile') return dockerfile.dockerfile;
  return switch (extension) {
    'dart' => dart.dart,
    'js' || 'mjs' || 'cjs' => javascript.javascript,
    'ts' || 'tsx' => typescript.typescript,
    'json' || 'jsonc' => json.json,
    'yaml' || 'yml' => yaml.yaml,
    'html' || 'htm' || 'xml' || 'svg' => xml.xml,
    'css' || 'scss' || 'less' => css.css,
    'py' => python.python,
    'java' => java.java,
    'kt' || 'kts' => kotlin.kotlin,
    'c' || 'cc' || 'cpp' || 'cxx' || 'h' || 'hpp' => cpp.cpp,
    'cs' => csharp.cs,
    'go' => go.go,
    'rs' => rust.rust,
    'php' => php.php,
    'rb' => ruby.ruby,
    'swift' => swift.swift,
    'sh' || 'bash' || 'zsh' || 'fish' => bash.bash,
    'sql' => sql.sql,
    'md' || 'markdown' => markdown.markdown,
    'ini' || 'cfg' || 'conf' || 'properties' => ini.ini,
    _ => null,
  };
}
