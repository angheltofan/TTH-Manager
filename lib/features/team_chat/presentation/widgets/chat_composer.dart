import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/team_chat_repository.dart';
import '../../domain/team_chat_message.dart';
import '../../providers/team_chat_providers.dart';

/// Whitelist for the image picker. Mirrors what the UI is built to
/// render inline; everything else routes through the file picker.
const _kImageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};

/// 25 MB — matches the bucket cap in
/// `20260622_team_chat_attachments_PROPOSED.sql`. The client check is
/// purely UX so the user sees a friendly message before a 25 MB upload
/// fails — server-side enforcement is the bucket's `file_size_limit`.
const _kMaxAttachmentBytes = 25 * 1024 * 1024;

/// Sender API. The composer pre-uploads any attachment so by the time
/// this fires the URL is final and the page just needs to insert the
/// row + scroll.
typedef SendChatMessage = Future<void> Function({
  String? body,
  UploadedAttachment? attachment,
});

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final SendChatMessage onSend;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  UploadedAttachment? _pending;
  bool _uploading = false;
  bool _sending = false;

  bool get _busy => _uploading || _sending;
  bool get _canSend =>
      !_busy &&
      (widget.controller.text.trim().isNotEmpty || _pending != null);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  // ── Attachment picking ────────────────────────────────────────────────

  Future<void> _openAttachmentSheet() async {
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _AttachmentSheet(),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _AttachmentChoice.photo:
        await _pickPhoto();
      case _AttachmentChoice.file:
        await _pickFile();
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    await _uploadPicked(
      bytes: bytes,
      fileName: picked.name.isEmpty ? 'photo.jpg' : picked.name,
      kind: ChatAttachmentKind.image,
      contentType: picked.mimeType,
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      _snack('Fișierul nu a putut fi citit.');
      return;
    }
    final ext = (f.extension ?? '').toLowerCase();
    final isImage = _kImageExtensions.contains(ext);
    await _uploadPicked(
      bytes: bytes,
      fileName: f.name,
      kind: isImage ? ChatAttachmentKind.image : ChatAttachmentKind.file,
      contentType: _guessMime(ext),
    );
  }

  Future<void> _uploadPicked({
    required Uint8List bytes,
    required String fileName,
    required ChatAttachmentKind kind,
    String? contentType,
  }) async {
    if (bytes.lengthInBytes > _kMaxAttachmentBytes) {
      _snack('Fișierul depășește 25 MB.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final uploaded =
          await ref.read(teamChatRepositoryProvider).uploadAttachment(
                bytes: bytes,
                fileName: fileName,
                kind: kind,
                contentType: contentType,
              );
      if (!mounted) return;
      setState(() => _pending = uploaded);
    } catch (e) {
      if (kDebugMode) debugPrint('[Chat] attachment upload failed: $e');
      if (mounted) _snack('Încărcare eșuată. Încearcă din nou.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _clearPending() => setState(() => _pending = null);

  // ── Send ──────────────────────────────────────────────────────────────

  Future<void> _send() async {
    if (!_canSend) return;
    final text = widget.controller.text.trim();
    final pending = _pending;
    setState(() => _sending = true);
    try {
      await widget.onSend(
        body: text.isEmpty ? null : text,
        attachment: pending,
      );
      if (!mounted) return;
      widget.controller.clear();
      setState(() => _pending = null);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String? _guessMime(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pillBg = theme.colorScheme.surface;
    final pillBorder = theme.colorScheme.outline
        .withValues(alpha: isDark ? 0.22 : 0.28);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pending != null || _uploading)
                _PendingAttachmentChip(
                  pending: _pending,
                  uploading: _uploading,
                  onClear: _busy ? null : _clearPending,
                ),
              Row(
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
                            tooltip: 'Atașează',
                            onTap: _busy ? null : _openAttachmentSheet,
                          ),
                          Expanded(
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                    shift: false): _send,
                              },
                              child: TextField(
                                controller: widget.controller,
                                enabled: !_sending,
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SendButton(
                    busy: _busy,
                    canSend: _canSend,
                    onSend: _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Attachment bottom sheet ────────────────────────────────────────────

enum _AttachmentChoice { photo, file }

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Text(
                    'Atașează',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            _SheetRow(
              icon: Icons.image_outlined,
              iconColor: AppColors.info,
              label: 'Foto sau imagine',
              subtitle: 'Din galerie • previzualizare în chat',
              onTap: () =>
                  Navigator.of(context).pop(_AttachmentChoice.photo),
            ),
            _SheetRow(
              icon: Icons.insert_drive_file_outlined,
              iconColor: AppColors.purple,
              label: 'Fișier sau document',
              subtitle: 'PDF, Word, Excel, alte fișiere',
              onTap: () =>
                  Navigator.of(context).pop(_AttachmentChoice.file),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Pending-attachment chip above the input pill ───────────────────────

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.pending,
    required this.uploading,
    required this.onClear,
  });
  final UploadedAttachment? pending;
  final bool uploading;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = pending?.kind == ChatAttachmentKind.image;
    final color = isImage ? AppColors.info : AppColors.purple;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            if (uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
                color: color,
                size: 18,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                uploading
                    ? 'Se încarcă…'
                    : (pending?.name ?? 'Atașament'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: Icon(Icons.close_rounded, color: color, size: 18),
                onPressed: onClear,
                tooltip: 'Elimină atașamentul',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(2),
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = Theme.of(context)
        .colorScheme
        .outline
        .withValues(alpha: disabled ? 0.5 : 0.85);
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
  const _SendButton({
    required this.busy,
    required this.canSend,
    required this.onSend,
  });
  final bool busy;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final enabled = canSend && !busy;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: busy
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
              color: enabled
                  ? AppColors.purple
                  : AppColors.purple.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onSend : null,
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
