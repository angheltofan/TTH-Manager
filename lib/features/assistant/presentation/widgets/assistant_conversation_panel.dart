import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/assistant_conversation.dart';
import 'assistant_conversation_item.dart';

/// Sidebar / drawer that lists the user's conversation history with
/// search + groupings (Favorite / Astăzi / Ultimele 7 zile / Mai vechi).
///
/// Pure presentation — every action calls back to the parent, which
/// owns the provider mutations.
class AssistantConversationPanel extends StatefulWidget {
  const AssistantConversationPanel({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.onOpen,
    required this.onNewConversation,
    required this.onRename,
    required this.onDelete,
    required this.onToggleFavorite,
    this.showCloseButton = false,
    this.onClose,
  });

  final List<AssistantConversation> conversations;
  final String? activeConversationId;
  final ValueChanged<String> onOpen;
  final VoidCallback onNewConversation;
  final void Function(AssistantConversation conv) onRename;
  final void Function(AssistantConversation conv) onDelete;
  final void Function(AssistantConversation conv) onToggleFavorite;

  /// Show a small X button in the header (mobile drawer use case).
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  State<AssistantConversationPanel> createState() =>
      _AssistantConversationPanelState();
}

class _AssistantConversationPanelState
    extends State<AssistantConversationPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered(widget.conversations, _query);
    final groups = _group(filtered);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Conversații',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (widget.showCloseButton)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Închide',
                    onPressed: widget.onClose,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: FilledButton.icon(
              onPressed: widget.onNewConversation,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Conversație nouă'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Caută conversație…',
                prefixIcon: const Icon(Icons.search, size: 16),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: theme.textTheme.bodySmall,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(query: _query)
                : ListView(
                    padding:
                        const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    children: [
                      for (final group in groups)
                        if (group.items.isNotEmpty) ...[
                          _SectionLabel(label: group.label),
                          for (final c in group.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: AssistantConversationItem(
                                conversation: c,
                                isActive:
                                    widget.activeConversationId == c.id,
                                onOpen: () => widget.onOpen(c.id),
                                onRename: () => widget.onRename(c),
                                onDelete: () => widget.onDelete(c),
                                onToggleFavorite: () =>
                                    widget.onToggleFavorite(c),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static List<AssistantConversation> _filtered(
    List<AssistantConversation> all,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) => c.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  static List<_Group> _group(List<AssistantConversation> list) {
    final favorites = <AssistantConversation>[];
    final today = <AssistantConversation>[];
    final week = <AssistantConversation>[];
    final older = <AssistantConversation>[];

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOf7d = startOfToday.subtract(const Duration(days: 6));

    for (final c in list) {
      if (c.isFavorite) {
        favorites.add(c);
        continue;
      }
      final ts = c.activityAt;
      if (!ts.isBefore(startOfToday)) {
        today.add(c);
      } else if (!ts.isBefore(startOf7d)) {
        week.add(c);
      } else {
        older.add(c);
      }
    }

    return [
      _Group(label: 'Favorite', items: favorites),
      _Group(label: 'Astăzi', items: today),
      _Group(label: 'Ultimele 7 zile', items: week),
      _Group(label: 'Mai vechi', items: older),
    ];
  }
}

class _Group {
  const _Group({required this.label, required this.items});
  final String label;
  final List<AssistantConversation> items;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.outline,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          query.isEmpty
              ? 'Nu există conversații încă.'
              : 'Nicio conversație nu se potrivește cu "$query".',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
