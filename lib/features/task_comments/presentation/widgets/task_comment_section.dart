import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/nostr_provider.dart';
import '../../domain/entities/task_comment.dart';
import '../../infrastructure/providers/repository_providers.dart';
import '../../infrastructure/repositories/task_comment_repository_impl.dart'
    show maxCommentBodyChars;
import '../providers/author_profile_providers.dart';
import '../providers/task_comment_providers.dart';

/// Comment thread ("task chat") section shown below SUBTASKS in the task
/// detail screen.
///
/// - Shared-list tasks pass [groupId]; personal tasks pass null.
/// - Personal comments are signable in both modes (secret-key and Amber).
///   Should a future unsignable state appear, the availability provider
///   replaces the input with an explicit notice instead of failing silently.
/// - Tombstones (`deleted: true`) arrive in the stream and are hidden here.
class TaskCommentSection extends ConsumerStatefulWidget {
  const TaskCommentSection({required this.taskId, this.groupId, super.key});

  /// Task the thread belongs to (payload-internal reference only).
  final String taskId;

  /// Shared-list group id, or null for personal tasks.
  final String? groupId;

  @override
  ConsumerState<TaskCommentSection> createState() => _TaskCommentSectionState();
}

class _TaskCommentSectionState extends ConsumerState<TaskCommentSection> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  bool _isSending = false;

  bool get _isPersonalTask => widget.groupId == null;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Keep the personal kind:35002 subscription alive while this section is
    // visible (shared-list events route through the existing shared-v1
    // subscription instead).
    if (_isPersonalTask) {
      ref.watch(personalTaskCommentSubscriptionProvider);
    }

    // The availability provider is synchronous, so there is no loading state.
    final canComment =
        !_isPersonalTask || ref.watch(personalCommentAvailabilityProvider);
    final showUnavailableNotice = !canComment;

    final commentsAsync = ref.watch(taskCommentsStreamProvider(widget.taskId));
    final visibleComments =
        commentsAsync.valueOrNull
            ?.where((comment) => !comment.deleted)
            .toList() ??
        const <TaskComment>[];
    final myPubkey = ref.watch(publicKeyProvider);

    final otherAuthorHexes = visibleComments
        .where(
          (comment) => myPubkey == null || comment.authorPubkey != myPubkey,
        )
        .map((comment) => comment.authorPubkey)
        .toSet();
    if (otherAuthorHexes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(authorLabelsProvider.notifier)
            .ensureLoaded(otherAuthorHexes.toList());
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.commentsHeader,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (visibleComments.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '${visibleComments.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary.withOpacity(0.7)
                        : AppTheme.lightTextSecondary.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Comment bubbles
          ...visibleComments.map(
            (comment) => _buildCommentBubble(
              context,
              comment,
              isMine: myPubkey != null && comment.authorPubkey == myPubkey,
              canModify: canComment,
              isDark: isDark,
              theme: theme,
              l10n: l10n,
            ),
          ),

          if (visibleComments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.noComments,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary.withOpacity(0.5)
                      : AppTheme.lightTextSecondary.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Input row, or an explicit notice while personal comments are
          // fail-closed (never a silently failing input).
          if (showUnavailableNotice)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary.withOpacity(0.6)
                        : AppTheme.lightTextSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.commentsUnavailableForTask,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? AppTheme.darkTextSecondary.withOpacity(0.6)
                            : AppTheme.lightTextSecondary.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildInputRow(context, isDark, theme, l10n, enabled: canComment),

          Divider(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(
    BuildContext context,
    TaskComment comment, {
    required bool isMine,
    required bool canModify,
    required bool isDark,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    final bubbleColor = isMine
        ? AppTheme.primaryPurple.withOpacity(isDark ? 0.28 : 0.12)
        : (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05));

    final timeLabel = _formatTimestamp(context, comment.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMine && canModify
            ? () => _showCommentActions(context, comment, l10n)
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) _buildAuthorLabel(comment.authorPubkey, isDark),
              Text(
                comment.body,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                comment.editedAt != null
                    ? '$timeLabel · ${l10n.commentEditedLabel}'
                    : timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.darkTextSecondary.withOpacity(0.7)
                      : AppTheme.lightTextSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Author attribution for other members' comments: kind:0 display name
  /// (when known) plus a shortened npub, shown side by side — the npub stays
  /// visible because shared-list authorship is self-asserted (every member
  /// signs with the same group key), so a display name alone is spoofable.
  Widget _buildAuthorLabel(String authorPubkeyHex, bool isDark) {
    final label = ref.watch(authorLabelsProvider)[authorPubkeyHex];
    final shortNpub =
        label?.shortNpub ?? _shortenIdentifierFallback(authorPubkeyHex);
    final displayName = label?.displayName;

    final npubStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: AppTheme.primaryColor.withOpacity(0.8),
    );
    final nameStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            if (displayName != null) ...[
              TextSpan(text: displayName, style: nameStyle),
              TextSpan(text: ' · ', style: npubStyle),
            ],
            TextSpan(text: shortNpub, style: npubStyle),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Placeholder shown before the async npub lookup for [authorPubkeyHex]
  /// resolves — the raw hex, shortened the same way a resolved npub would be.
  String _shortenIdentifierFallback(String authorPubkeyHex) {
    if (authorPubkeyHex.length <= 20) {
      return authorPubkeyHex;
    }
    final prefix = authorPubkeyHex.substring(0, 12);
    final suffix = authorPubkeyHex.substring(authorPubkeyHex.length - 6);
    return '$prefix…$suffix';
  }

  Widget _buildInputRow(
    BuildContext context,
    bool isDark,
    ThemeData theme,
    AppLocalizations l10n, {
    required bool enabled,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            enabled: enabled && !_isSending,
            keyboardType: TextInputType.multiline,
            maxLength: maxCommentBodyChars,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: l10n.addCommentHint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.5)
                    : AppTheme.lightTextSecondary.withOpacity(0.5),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
          ),
        ),
        IconButton(
          icon: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 18),
          color: AppTheme.primaryPurple,
          onPressed: enabled && !_isSending ? _submitComment : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: l10n.addCommentHint,
        ),
      ],
    );
  }

  Future<void> _submitComment() async {
    final body = _inputController.text.trim();
    if (body.isEmpty) {
      return;
    }

    setState(() => _isSending = true);
    final result = await ref
        .read(taskCommentRepositoryProvider)
        .addComment(taskId: widget.taskId, body: body, groupId: widget.groupId);
    if (!mounted) {
      return;
    }
    setState(() => _isSending = false);

    result.fold(
      (failure) => _showFailure(failure.message),
      (_) {
        _inputController.clear();
        _inputFocusNode.requestFocus();
      },
    );
  }

  void _showCommentActions(
    BuildContext context,
    TaskComment comment,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text(l10n.editCommentTitle),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditDialog(comment, l10n);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red.shade400,
              ),
              title: Text(
                l10n.deleteButton,
                style: TextStyle(color: Colors.red.shade400),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(comment, l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    TaskComment comment,
    AppLocalizations l10n,
  ) async {
    final editController = TextEditingController(text: comment.body);
    final newBody = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editCommentTitle),
        content: TextField(
          controller: editController,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLength: maxCommentBodyChars,
          minLines: 1,
          maxLines: 6,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, editController.text),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
    editController.dispose();

    final trimmed = newBody?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == comment.body) {
      return;
    }
    if (!mounted) {
      return;
    }

    final result = await ref
        .read(taskCommentRepositoryProvider)
        .editComment(
          comment: comment,
          newBody: trimmed,
          groupId: widget.groupId,
        );
    if (!mounted) {
      return;
    }
    result.fold((failure) => _showFailure(failure.message), (_) {});
  }

  Future<void> _confirmDelete(
    TaskComment comment,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteCommentConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.deleteButton,
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final result = await ref
        .read(taskCommentRepositoryProvider)
        .deleteComment(
          comment: comment,
          groupId: widget.groupId,
        );
    if (!mounted) {
      return;
    }
    result.fold((failure) => _showFailure(failure.message), (_) {});
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  String _formatTimestamp(BuildContext context, int epochSeconds) {
    final locale = Localizations.localeOf(context).toString();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return DateFormat.MMMd(locale).add_Hm().format(dateTime);
  }
}
