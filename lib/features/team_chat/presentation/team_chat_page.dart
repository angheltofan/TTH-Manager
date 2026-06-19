import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/team_chat_message.dart';
import '../providers/team_chat_providers.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_messages_list.dart';

/// Team chat — UI shell.
///
/// All state semantics (read-tracking, scroll-to-newest, delete menu,
/// realtime listener, lifecycle) preserved from the previous monolithic
/// implementation. The visual layer was extracted to `widgets/` for the
/// production-grade messaging look — backend logic untouched.
class TeamChatPage extends ConsumerStatefulWidget {
  const TeamChatPage({super.key});

  @override
  ConsumerState<TeamChatPage> createState() => _TeamChatPageState();
}

class _TeamChatPageState extends ConsumerState<TeamChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  DateTime? _previousLastReadAt;
  bool _capturedPreviousLastRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cached = ref.read(teamChatMessagesProvider);
      if (cached.hasValue) _onMessagesAvailable(cached.valueOrNull);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// With reverse:true, offset 0 is the visual bottom (newest messages).
  void _scrollToNewest() {
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  void _onMessagesAvailable(List<TeamChatMessage>? msgs) {
    if (!_capturedPreviousLastRead) {
      _previousLastReadAt = ref.read(chatLastReadAtProvider);
      _capturedPreviousLastRead = true;
      if (kDebugMode) {
        debugPrint('[Chat] captured previousLastReadAt=$_previousLastReadAt');
      }
      if (mounted) setState(() {});
    }

    _scrollToNewest();

    final newestTime = (msgs != null && msgs.isNotEmpty)
        ? msgs.first.createdAt
        : DateTime.now();
    ref.read(chatLastReadAtProvider.notifier).markRead(newestTime);
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(teamChatRepositoryProvider).sendMessage(body: body);
      _msgCtrl.clear();
      _scrollToNewest();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesajul nu a putut fi trimis.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final isStaff = profile?.isStaff ?? false;
    try {
      await ref.read(teamChatRepositoryProvider).softDeleteMessage(
            messageId: messageId,
            currentUserId: user.id,
            isStaff: isStaff,
            isAdmin: isAdmin,
          );
      ref.invalidate(teamChatMessagesProvider);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la ștergere: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesajul nu a putut fi șters.')),
        );
      }
    }
  }

  void _showDeleteMenu(
      BuildContext ctx, Offset globalPosition, String messageId) {
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Șterge mesaj',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete' && mounted) _deleteMessage(messageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStaff = profile != null && (profile.isAdmin || profile.isTrainer);

    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
          ),
          title: const Text('Chat echipă'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nu ai acces la chatul echipei.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final messagesAsync = ref.watch(teamChatMessagesProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final theme = Theme.of(context);

    ref.listen<AsyncValue<List<TeamChatMessage>>>(teamChatMessagesProvider,
        (prev, next) {
      if (!next.hasValue) return;
      _onMessagesAvailable(next.valueOrNull);
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: const ChatAppBar(
        title: 'Chat echipă',
        subtitle: 'Grup intern',
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Eroare: $e'),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Niciun mesaj încă.\nFii primul care scrie!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    );
                  }
                  final items = buildChatItems(
                    messages,
                    previousLastReadAt: _previousLastReadAt,
                    currentUserId: currentUserId,
                  );
                  return ChatMessagesList(
                    items: items,
                    currentUserId: currentUserId,
                    canDeleteForAdmin: profile.isAdmin,
                    scrollController: _scrollCtrl,
                    onDeleteRequested: (pos, id) =>
                        _showDeleteMenu(context, pos, id),
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outline
                  .withValues(alpha: theme.brightness == Brightness.dark
                      ? 0.18
                      : 0.22),
            ),
            ChatComposer(
              controller: _msgCtrl,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}
