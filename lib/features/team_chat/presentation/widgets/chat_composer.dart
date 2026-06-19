import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Modern messaging-app composer.
///
/// Single rounded pill that hosts an attachment button (leading), the text
/// field, the emoji button, and an animated send button on the right.
/// Sits flush at the bottom of the chat, respects safe-area insets, and
/// rises with the soft keyboard via [Scaffold.resizeToAvoidBottomInset].
///
/// Emoji and attachment are visual scaffolding for upcoming features —
/// they surface a friendly notice today and remain wired for a future
/// implementation without changing the layout.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  void _notImplemented(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — disponibilă în curând.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pillBg = isDark
        ? theme.colorScheme.surface
        : theme.colorScheme.surface;
    final pillBorder = theme.colorScheme.outline
        .withValues(alpha: isDark ? 0.22 : 0.28);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: pillBorder, width: 0.8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _IconAction(
                        icon: Icons.attach_file_rounded,
                        tooltip: 'Atașează fișier',
                        onTap: () =>
                            _notImplemented(context, 'Atașarea fișierelor'),
                      ),
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.enter,
                                shift: false): onSend,
                          },
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Scrie un mesaj…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                              filled: false,
                            ),
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.32,
                            ),
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),
                      _IconAction(
                        icon: Icons.emoji_emotions_outlined,
                        tooltip: 'Emoji',
                        onTap: () => _notImplemented(context, 'Emoji'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _SendButton(sending: sending, onSend: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.85);
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onTap,
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: sending
          ? const SizedBox(
              key: ValueKey('chat-send-loading'),
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.purple,
                  ),
                ),
              ),
            )
          : Material(
              key: const ValueKey('chat-send-button'),
              color: AppColors.purple,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
    );
  }
}
