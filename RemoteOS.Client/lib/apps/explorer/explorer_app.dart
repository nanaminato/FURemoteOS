import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_service.dart';
import '../../core/network/remoteos_api.dart';
import '../../features/files/data/remote_file_api.dart';

/// File Explorer migration.  Its panes mirror the Avalonia explorer: location
/// tree, command bar, editable breadcrumb and detail list.  The view is kept
/// independent from transport so server file DTOs can be bound here directly.
class ExplorerApp extends ConsumerStatefulWidget {
  const ExplorerApp({super.key});

  @override
  ConsumerState<ExplorerApp> createState() => _ExplorerAppState();
}

class _ExplorerAppState extends ConsumerState<ExplorerApp> {
  String _location = 'Home';
  String _path = '/home/user';
  final _search = TextEditingController();
  final _address = TextEditingController(text: '/home/user');
  bool _detailsView = true;
  List<_FileEntry> _entries = const [];
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _search.dispose();
    _address.dispose();
    super.dispose();
  }

  void _navigate(String location, String path) {
    setState(() {
      _location = location;
      _path = path;
      _address.text = path;
    });
    _load(path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result =
          await RemoteFileApi(ref.read(remoteOsApiProvider)).list(path);
      if (!mounted || path != _path) return;
      setState(() {
        _entries = result.map(_FileEntry.fromRemote).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || path != _path) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _loadInitial() async {
    try {
      final api = RemoteFileApi(ref.read(remoteOsApiProvider));
      final locations = await api.specialLocations();
      final home = locations
          .where((location) => location.name.toLowerCase() == 'home')
          .firstOrNull;
      if (home != null && mounted) {
        setState(() {
          _location = home.name;
          _path = home.path;
          _address.text = home.path;
        });
      }
    } catch (_) {
      // Older servers may not expose SpecialLocations; list still preserves
      // compatibility with their file endpoint.
    }
    if (mounted) _load(_path);
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 680;
      return Column(children: [
        _commandBar(palette),
        _addressBar(palette),
        Expanded(
          child: compact
              ? _content(palette, showTree: false)
              : Row(children: [
                  _tree(palette),
                  VerticalDivider(
                      width: 1, thickness: 1, color: palette.borderSubtle),
                  Expanded(child: _content(palette, showTree: false)),
                ]),
        ),
        _statusBar(palette),
      ]);
    });
  }

  Widget _commandBar(ThemePalette palette) => Container(
        height: 48,
        color: palette.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          _toolButton(palette, Icons.arrow_back_rounded, 'Back'),
          _toolButton(palette, Icons.arrow_forward_rounded, 'Forward'),
          _toolButton(palette, Icons.arrow_upward_rounded, 'Up', onPressed: () {
            final slash = _path.lastIndexOf('/');
            if (slash > 0)
              _navigate(_path.substring(0, slash).split('/').last,
                  _path.substring(0, slash));
          }),
          Container(
              width: 1,
              height: 22,
              color: palette.borderSubtle,
              margin: const EdgeInsets.symmetric(horizontal: 6)),
          _toolButton(palette, Icons.refresh_rounded, 'Refresh',
              onPressed: () => _load(_path)),
          _toolButton(palette, Icons.content_copy_outlined, 'Copy'),
          _toolButton(palette, Icons.content_cut_outlined, 'Cut'),
          _toolButton(palette, Icons.paste_outlined, 'Paste'),
          const Spacer(),
          IconButton(
            tooltip: _detailsView ? 'Icon view' : 'Details view',
            onPressed: () => setState(() => _detailsView = !_detailsView),
            icon: Icon(
                _detailsView
                    ? Icons.grid_view_rounded
                    : Icons.view_list_rounded,
                color: palette.textSecondary),
          ),
        ]),
      );

  Widget _toolButton(ThemePalette palette, IconData icon, String label,
          {VoidCallback? onPressed}) =>
      TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
            foregroundColor: palette.textSecondary,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      );

  Widget _addressBar(ThemePalette palette) => Container(
        height: 48,
        color: palette.surface,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(children: [
          Icon(Icons.folder_outlined, size: 18, color: palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _address,
              onSubmitted: (value) =>
                  _navigate(value.split('/').lastOrNull ?? 'Location', value),
              style: TextStyle(fontSize: 13, color: palette.textPrimary),
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4))),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 188,
            child: TextField(
              controller: _search,
              style: TextStyle(fontSize: 12, color: palette.textPrimary),
              decoration: InputDecoration(
                  hintText: 'Search $_location',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4))),
            ),
          ),
        ]),
      );

  Widget _tree(ThemePalette palette) => SizedBox(
        width: 208,
        child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _treeHeading(palette, 'Quick access'),
              _treeItem(palette, 'Home', Icons.home_outlined, '/home/user'),
              _treeItem(palette, 'Desktop', Icons.desktop_windows_outlined,
                  '/home/user/Desktop'),
              _treeItem(palette, 'Documents', Icons.description_outlined,
                  '/home/user/Documents'),
              _treeItem(palette, 'Downloads', Icons.download_outlined,
                  '/home/user/Downloads'),
              _treeItem(palette, 'Pictures', Icons.image_outlined,
                  '/home/user/Pictures'),
              const SizedBox(height: 8),
              _treeHeading(palette, 'This PC'),
              _treeItem(palette, 'File system', Icons.storage_outlined, '/'),
              _treeItem(palette, 'Remote workspace', Icons.cloud_outlined,
                  '/workspace'),
            ]),
      );

  Widget _treeHeading(ThemePalette palette, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 5),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
                color: palette.textTertiary)),
      );

  Widget _treeItem(
      ThemePalette palette, String label, IconData icon, String path) {
    final selected = label == _location;
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigate(label, path),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: selected ? palette.accentMuted : Colors.transparent,
                border: selected
                    ? Border(left: BorderSide(color: palette.accent, width: 3))
                    : null),
            child: Row(children: [
              Icon(icon,
                  size: 18,
                  color: selected ? palette.accent : palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 13, color: palette.textPrimary)))
            ]),
          ),
        ));
  }

  Widget _content(ThemePalette palette, {required bool showTree}) {
    final filter = _search.text.trim().toLowerCase();
    final entries = filter.isEmpty
        ? _entries
        : _entries
            .where((entry) => entry.name.toLowerCase().contains(filter))
            .toList();
    return Container(
      color: palette.appBackground,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_location,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary)),
              const SizedBox(height: 3),
              Text(_path,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            ])),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                'Unable to load this directory.\n$_loadError',
                                textAlign: TextAlign.center)))
                    : _detailsView
                        ? _details(palette, entries)
                        : _iconGrid(palette, entries)),
      ]),
    );
  }

  Widget _details(ThemePalette palette, List<_FileEntry> entries) =>
      ListView(children: [
        Container(
            height: 34,
            color: palette.surfaceSunken,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _column('Name', 3, palette),
              _column('Date modified', 2, palette),
              _column('Type', 2, palette),
              _column('Size', 1, palette),
            ])),
        for (final entry in entries) _entryRow(palette, entry),
      ]);

  Widget _column(String text, int flex, ThemePalette palette) => Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary)));

  Widget _entryRow(ThemePalette palette, _FileEntry entry) => Material(
      color: Colors.transparent,
      child: InkWell(
        onDoubleTap: entry.type == 'Folder'
            ? () => _navigate(entry.name, entry.path)
            : null,
        child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    Icon(entry.icon,
                        size: 19,
                        color: entry.type == 'Folder'
                            ? const Color(0xFFE9A23B)
                            : palette.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(entry.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: palette.textPrimary)))
                  ])),
              _column(entry.modified, 2, palette),
              _column(entry.type, 2, palette),
              _column(entry.size, 1, palette),
            ])),
      ));

  Widget _iconGrid(ThemePalette palette, List<_FileEntry> entries) =>
      GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: entries.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisExtent: 112,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10),
        itemBuilder: (_, index) {
          final entry = entries[index];
          return InkWell(
              onDoubleTap: entry.type == 'Folder'
                  ? () => _navigate(entry.name, entry.path)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.icon,
                        size: 42,
                        color: entry.type == 'Folder'
                            ? const Color(0xFFE9A23B)
                            : palette.textSecondary),
                    const SizedBox(height: 7),
                    Text(entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: palette.textPrimary))
                  ]));
        },
      );

  Widget _statusBar(ThemePalette palette) => Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.borderSubtle))),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              '${_entries.length} items${_loading ? ' · Loading…' : ''}',
              style: TextStyle(fontSize: 11, color: palette.textTertiary))));
}

class _FileEntry {
  const _FileEntry(
      this.name, this.path, this.type, this.size, this.modified, this.icon);
  final String name;
  final String path;
  final String type;
  final String size;
  final String modified;
  final IconData icon;

  factory _FileEntry.fromRemote(RemoteFileEntry entry) => _FileEntry(
        entry.name,
        entry.path,
        entry.isDirectory ? 'Folder' : 'File',
        entry.size == null ? '—' : _formatBytes(entry.size!),
        entry.lastWriteTime?.toLocal().toString().split('.').first ?? '—',
        entry.isDirectory ? Icons.folder_rounded : Icons.description_outlined,
      );

  static String _formatBytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}

extension on Iterable<RemoteSpecialLocation> {
  RemoteSpecialLocation? get firstOrNull => isEmpty ? null : first;
}
