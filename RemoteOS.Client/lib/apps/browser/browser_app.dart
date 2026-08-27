import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_service.dart';

/// Browser shell migrated from the Avalonia client.  Navigation history and
/// bookmarks are client-side state; rendering external pages remains platform
/// delegated (the original Linux client used the system browser for the same
/// reason), while server history/bookmark APIs can be wired in below.
class BrowserApp extends ConsumerStatefulWidget {
  const BrowserApp({super.key});

  @override
  ConsumerState<BrowserApp> createState() => _BrowserAppState();
}

class _BrowserAppState extends ConsumerState<BrowserApp> {
  final _address = TextEditingController(text: 'remoteos://home');
  final List<_BrowserEntry> _history = [];
  final List<_BrowserEntry> _bookmarks = [
    const _BrowserEntry('RemoteOS home', 'remoteos://home'),
  ];
  bool _showSidebar = true;
  bool _bookmarksTab = true;
  int _historyIndex = -1;
  String _current = 'remoteos://home';

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  bool get _isBookmarked => _bookmarks.any((entry) => entry.url == _current);

  void _navigate([String? value]) {
    var target = (value ?? _address.text).trim();
    if (target.isEmpty) return;
    if (!target.contains('://')) target = 'https://$target';
    setState(() {
      _history.removeRange(_historyIndex + 1, _history.length);
      final item = _BrowserEntry(_titleFor(target), target);
      _history.add(item);
      _historyIndex = _history.length - 1;
      _current = target;
      _address.text = target;
    });
  }

  void _back() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _current = _history[_historyIndex].url;
        _address.text = _current;
      });
    }
  }

  void _forward() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _current = _history[_historyIndex].url;
        _address.text = _current;
      });
    }
  }

  void _toggleBookmark() => setState(() {
        final index = _bookmarks.indexWhere((entry) => entry.url == _current);
        if (index >= 0) {
          _bookmarks.removeAt(index);
        } else {
          _bookmarks.add(_BrowserEntry(_titleFor(_current), _current));
        }
      });

  String _titleFor(String url) => url == 'remoteos://home'
      ? 'RemoteOS home'
      : Uri.tryParse(url)?.host ?? url;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return Column(children: [
      _toolbar(palette),
      _addressBar(palette),
      Expanded(
          child: Row(children: [
        if (_showSidebar) _sidebar(palette),
        if (_showSidebar)
          VerticalDivider(width: 1, thickness: 1, color: palette.borderSubtle),
        Expanded(child: _page(palette)),
      ])),
      _status(palette),
    ]);
  }

  Widget _toolbar(ThemePalette palette) => Container(
        height: 46,
        color: palette.surface,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(children: [
          IconButton(
              onPressed: _historyIndex > 0 ? _back : null,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded, size: 20)),
          IconButton(
              onPressed: _historyIndex < _history.length - 1 ? _forward : null,
              tooltip: 'Forward',
              icon: const Icon(Icons.arrow_forward_rounded, size: 20)),
          IconButton(
              onPressed: () => _navigate(_current),
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, size: 20)),
          IconButton(
              onPressed: () => _navigate('remoteos://home'),
              tooltip: 'Home',
              icon: const Icon(Icons.home_outlined, size: 20)),
          Container(
              width: 1,
              height: 22,
              color: palette.borderSubtle,
              margin: const EdgeInsets.symmetric(horizontal: 5)),
          IconButton(
              onPressed: _toggleBookmark,
              tooltip: 'Bookmark this page',
              icon: Icon(
                  _isBookmarked
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _isBookmarked ? const Color(0xFFE8A328) : null,
                  size: 21)),
          IconButton(
              onPressed: () => setState(() => _showSidebar = !_showSidebar),
              tooltip: 'Toggle sidebar',
              icon: const Icon(Icons.vertical_split_outlined, size: 20)),
          const Spacer(),
          TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Settings')),
        ]),
      );

  Widget _addressBar(ThemePalette palette) => Container(
        height: 49,
        color: palette.surface,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.borderSubtle))),
        child: Row(children: [
          Icon(
              _current.startsWith('https://')
                  ? Icons.lock_outline_rounded
                  : Icons.info_outline_rounded,
              size: 18,
              color: _current.startsWith('https://')
                  ? const Color(0xFF2E9D61)
                  : palette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _address,
                  onSubmitted: _navigate,
                  style: TextStyle(fontSize: 13, color: palette.textPrimary),
                  decoration: InputDecoration(
                      hintText: 'Search or enter address',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18))))),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: _navigate,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: const Text('Go')),
        ]),
      );

  Widget _sidebar(ThemePalette palette) => SizedBox(
        width: 255,
        child: Column(children: [
          Container(
              height: 44,
              color: palette.surface,
              child: Row(children: [
                _sideTab(palette, 'Bookmarks', Icons.bookmark_outline_rounded,
                    _bookmarksTab, () => setState(() => _bookmarksTab = true)),
                _sideTab(
                    palette,
                    'History',
                    Icons.history_rounded,
                    !_bookmarksTab,
                    () => setState(() => _bookmarksTab = false)),
              ])),
          Expanded(
              child: ListView(children: [
            for (final entry in _bookmarksTab ? _bookmarks : _history)
              _sideEntry(palette, entry)
          ])),
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.borderSubtle))),
              child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: () => setState(() {
                            if (_bookmarksTab)
                              _bookmarks.clear();
                            else {
                              _history.clear();
                              _historyIndex = -1;
                            }
                          }),
                      child: Text(_bookmarksTab
                          ? 'Clear bookmarks'
                          : 'Clear history')))),
        ]),
      );

  Widget _sideTab(ThemePalette palette, String label, IconData icon,
          bool selected, VoidCallback onTap) =>
      Expanded(
          child: InkWell(
              onTap: onTap,
              child: Container(
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: selected
                                  ? palette.accent
                                  : Colors.transparent,
                              width: 2))),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: selected
                                ? palette.accent
                                : palette.textSecondary),
                        const SizedBox(width: 5),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? palette.textPrimary
                                    : palette.textSecondary))
                      ]))));

  Widget _sideEntry(ThemePalette palette, _BrowserEntry entry) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: () => _navigate(entry.url),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(children: [
                Icon(
                    _bookmarksTab
                        ? Icons.bookmark_outline_rounded
                        : Icons.history_rounded,
                    size: 16,
                    color: palette.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: palette.textPrimary)),
                      const SizedBox(height: 2),
                      Text(entry.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: palette.textTertiary))
                    ]))
              ]))));

  Widget _page(ThemePalette palette) => Container(
        color: palette.appBackground,
        child: _current == 'remoteos://home'
            ? _home(palette)
            : Center(
                child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_browser_rounded,
                          size: 52, color: palette.accent),
                      const SizedBox(height: 16),
                      Text(_titleFor(_current),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary)),
                      const SizedBox(height: 8),
                      Text(_current,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: palette.textSecondary)),
                      const SizedBox(height: 18),
                      Text(
                          'External web pages are delegated to the platform browser on this host. Your bookmarks and history remain available in RemoteOS.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: palette.textTertiary))
                    ]))),
      );

  Widget _home(ThemePalette palette) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                        color: palette.accentMuted,
                        borderRadius: BorderRadius.circular(18)),
                    child: Icon(Icons.public_rounded,
                        color: palette.accent, size: 34)),
                const SizedBox(height: 18),
                Text('RemoteOS Browser',
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary)),
                const SizedBox(height: 8),
                Text('Search the web or enter an address to navigate.',
                    style:
                        TextStyle(fontSize: 13, color: palette.textSecondary)),
                const SizedBox(height: 22),
                TextField(
                    onSubmitted: _navigate,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search or enter a URL',
                        border: OutlineInputBorder()))
              ]))));

  Widget _status(ThemePalette palette) => Container(
      height: 26,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(_current,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: palette.textTertiary)));
}

class _BrowserEntry {
  const _BrowserEntry(this.title, this.url);
  final String title;
  final String url;
}
