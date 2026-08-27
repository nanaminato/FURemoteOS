import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_service.dart';

/// A page descriptor shared by the Avalonia-style administration workspaces.
/// Keeping navigation and page content separate lets each application add pages
/// without reimplementing its window shell.
class WorkspacePage {
  const WorkspacePage({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// The common split-pane shell used by server-management applications.
/// It intentionally follows the original Avalonia workspaces: an application
/// rail, a page title/action row and a scrollable page body.
class WorkspaceScaffold extends ConsumerStatefulWidget {
  const WorkspaceScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.pages,
    this.actions = const [],
  });

  final String title;
  final IconData icon;
  final List<WorkspacePage> pages;
  final List<Widget> actions;

  @override
  ConsumerState<WorkspaceScaffold> createState() => _WorkspaceScaffoldState();
}

class _WorkspaceScaffoldState extends ConsumerState<WorkspaceScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final page = widget.pages[_selectedIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 660;
        return Column(
          children: [
            _AppHeader(
              title: widget.title,
              icon: widget.icon,
              palette: palette,
              actions: widget.actions,
            ),
            Expanded(
              child: compact
                  ? Column(
                      children: [
                        _CompactPagePicker(
                          pages: widget.pages,
                          selectedIndex: _selectedIndex,
                          onSelected: (index) =>
                              setState(() => _selectedIndex = index),
                          palette: palette,
                        ),
                        Expanded(
                            child: _PageCanvas(page: page, palette: palette)),
                      ],
                    )
                  : Row(
                      children: [
                        _NavigationRail(
                          pages: widget.pages,
                          selectedIndex: _selectedIndex,
                          onSelected: (index) =>
                              setState(() => _selectedIndex = index),
                          palette: palette,
                        ),
                        VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: palette.borderSubtle),
                        Expanded(
                            child: _PageCanvas(page: page, palette: palette)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.title,
    required this.icon,
    required this.palette,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final ThemePalette palette;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(bottom: BorderSide(color: palette.borderSubtle)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
            ...actions,
          ],
        ),
      );
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.pages,
    required this.selectedIndex,
    required this.onSelected,
    required this.palette,
  });

  final List<WorkspacePage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
        width: 208,
        color: palette.surface,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text('WORKSPACE',
                  style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            for (var index = 0; index < pages.length; index++)
              _NavigationItem(
                page: pages[index],
                selected: selectedIndex == index,
                palette: palette,
                onTap: () => onSelected(index),
              ),
          ],
        ),
      );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem(
      {required this.page,
      required this.selected,
      required this.palette,
      required this.onTap});

  final WorkspacePage page;
  final bool selected;
  final ThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? palette.accentMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: selected
                  ? Border.all(color: palette.accent.withOpacity(0.25))
                  : null,
            ),
            child: Row(
              children: [
                Icon(page.icon,
                    size: 18,
                    color: selected ? palette.accent : palette.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(page.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: palette.textPrimary))),
              ],
            ),
          ),
        ),
      );
}

class _CompactPagePicker extends StatelessWidget {
  const _CompactPagePicker(
      {required this.pages,
      required this.selectedIndex,
      required this.onSelected,
      required this.palette});

  final List<WorkspacePage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        color: palette.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: DropdownButtonFormField<int>(
          value: selectedIndex,
          isExpanded: true,
          decoration: const InputDecoration(
              isDense: true, border: OutlineInputBorder()),
          items: [
            for (var index = 0; index < pages.length; index++)
              DropdownMenuItem(
                  value: index,
                  child: Text(pages[index].title,
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
      );
}

class _PageCanvas extends StatelessWidget {
  const _PageCanvas({required this.page, required this.palette});

  final WorkspacePage page;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
        color: palette.appBackground,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: page.builder(context),
        ),
      );
}

/// Reusable overview used by each migrated management page.  It displays the
/// original client's data-dense card/table shape while a typed API client is
/// introduced page by page.
class WorkspaceOverview extends ConsumerWidget {
  const WorkspaceOverview({
    super.key,
    required this.title,
    required this.description,
    required this.metrics,
    required this.columns,
    required this.rows,
    this.primaryAction,
    this.onPrimaryAction,
    this.emptyMessage,
  });

  final String title;
  final String description;
  final List<WorkspaceMetric> metrics;
  final List<String> columns;
  final List<List<String>> rows;
  final String? primaryAction;
  final VoidCallback? onPrimaryAction;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary)),
                  const SizedBox(height: 5),
                  Text(description,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: palette.textSecondary)),
                ])),
            if (primaryAction != null) ...[
              const SizedBox(width: 16),
              FilledButton.icon(
                  onPressed: onPrimaryAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(primaryAction!)),
            ],
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth < 520
                ? 1
                : constraints.maxWidth < 780
                    ? 2
                    : metrics.length.clamp(1, 4);
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.6,
              children: [
                for (final metric in metrics)
                  _MetricCard(metric: metric, palette: palette)
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _DataCard(
            columns: columns,
            rows: rows,
            emptyMessage: emptyMessage,
            palette: palette),
      ],
    );
  }
}

class WorkspaceMetric {
  const WorkspaceMetric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.palette});
  final WorkspaceMetric metric;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.borderSubtle)),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: metric.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(metric.icon, color: metric.color, size: 19)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(metric.value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary)),
                Text(metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: palette.textSecondary)),
              ])),
        ]),
      );
}

class _DataCard extends StatelessWidget {
  const _DataCard(
      {required this.columns,
      required this.rows,
      required this.emptyMessage,
      required this.palette});
  final List<String> columns;
  final List<List<String>> rows;
  final String? emptyMessage;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.borderSubtle)),
        clipBehavior: Clip.antiAlias,
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                    child: Text(emptyMessage ?? 'No items to display.',
                        style: TextStyle(color: palette.textSecondary))))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStatePropertyAll(palette.surfaceSunken),
                  columns: [
                    for (final column in columns)
                      DataColumn(
                          label: Text(column,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textSecondary)))
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(cells: [
                        for (final value in row)
                          DataCell(Text(value,
                              style: TextStyle(
                                  fontSize: 12, color: palette.textPrimary)))
                      ]),
                  ],
                ),
              ),
      );
}
