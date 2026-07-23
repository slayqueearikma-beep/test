import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) return const [];
  return apiServiceProvider.fetchConversations();
});

final conversationsUnreadCountProvider = Provider.autoDispose<AsyncValue<int>>(
  (ref) {
    return ref.watch(conversationsProvider).whenData(
          (items) => items.fold<int>(0, (sum, c) => sum + c.unreadCount),
        );
  },
);

class MessagesInboxScreen extends ConsumerStatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  ConsumerState<MessagesInboxScreen> createState() =>
      _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
    final conversationsAsync = ref.watch(conversationsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.navMessages,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.searchConversations,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: isGuest
                ? _GuestMessagesEmpty(onLogin: () => context.push('/login'))
                : conversationsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AsyncErrorView.fromError(
                      e,
                      onRetry: () => ref.invalidate(conversationsProvider),
                    ),
                    data: (conversations) {
                      final filtered = _query.isEmpty
                          ? conversations
                          : conversations
                              .where((c) =>
                                  c.peerName.toLowerCase().contains(_query) ||
                                  c.lastMessagePreview
                                      .toLowerCase()
                                      .contains(_query))
                              .toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.noConversationsYet,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                FilledButton.icon(
                                  onPressed: () => context.push('/search'),
                                  icon: const Icon(Icons.search_rounded),
                                  label: Text(l10n.findPeopleToMessage),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(conversationsProvider),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final conversation = filtered[index];
                            return _ConversationTile(
                              conversation: conversation,
                              onTap: () => context.push(
                                '/messages/${conversation.id}',
                                extra: conversation,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GuestMessagesEmpty extends StatelessWidget {
  const _GuestMessagesEmpty({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.signInToMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.signInToMessageSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onLogin, child: Text(l10n.logIn)),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = conversation.peerName.isNotEmpty
        ? conversation.peerName.substring(0, 1).toUpperCase()
        : '?';
    final timeLabel = _formatTimestamp(conversation.lastMessageAt);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: 6,
      ),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.peerName.isEmpty
                  ? 'Conversation'
                  : conversation.peerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                    conversation.hasUnread ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            timeLabel,
            style: TextStyle(
              fontSize: 12,
              color: conversation.hasUnread
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontWeight:
                  conversation.hasUnread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessagePreview.isEmpty
                  ? 'Tap to open conversation'
                  : conversation.lastMessagePreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: conversation.hasUnread
                    ? Theme.of(context).colorScheme.onSurface
                    : AppColors.textSecondary,
                fontWeight:
                    conversation.hasUnread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (conversation.hasUnread) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '';
    final now = DateTime.now();
    final sameDay = parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (sameDay) {
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${parsed.day}/${parsed.month}';
  }
}

class ConversationThreadScreen extends ConsumerStatefulWidget {
  const ConversationThreadScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  final String conversationId;
  final ConversationModel? conversation;

  @override
  ConsumerState<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState
    extends ConsumerState<ConversationThreadScreen> {
  final _controller = TextEditingController();
  late Future<List<ChatMessageModel>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = apiServiceProvider.fetchConversationMessages(widget.conversationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await apiServiceProvider.replyToConversation(widget.conversationId, body);
      _controller.clear();
      setState(() {
        _future =
            apiServiceProvider.fetchConversationMessages(widget.conversationId);
      });
      ref.invalidate(conversationsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.conversation?.peerName.isNotEmpty == true
        ? widget.conversation!.peerName
        : l10n.navMessages;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ChatMessageModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AsyncErrorView.fromError(
                    snapshot.error!,
                    onRetry: () => setState(() {
                      _future = apiServiceProvider
                          .fetchConversationMessages(widget.conversationId);
                    }),
                  );
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return Center(child: Text(l10n.noMessagesYet));
                }
                final myId = ref.watch(authSessionProvider)?.user.id;
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final mine =
                        myId != null && message.senderId.isNotEmpty && message.senderId == myId;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.cardSelected,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.body,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.typeMessage,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
