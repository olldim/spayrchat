import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chat_controller.dart';
import '../models.dart';
import 'call_panel.dart';
import 'conversation_dialog.dart';
import 'theme.dart';

class ChatScreen extends StatefulWidget {
  final ChatController controller;
  const ChatScreen({super.key, required this.controller});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _filter = '';
  bool _unreadOnly = false;
  ChatController get c => widget.controller;

  void _newChat() => showDialog(
    context: context,
    builder: (_) => ConversationDialog(controller: c),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840,
          rail = constraints.maxWidth >= 1120;
      final showList = wide || c.selected == null;
      return PopScope(
        canPop: wide || c.selectedId == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) c.select(null);
        },
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (rail) _rail(),
                if (showList)
                  SizedBox(
                    width: wide ? 316 : constraints.maxWidth,
                    child: _sidebar(wide, rail),
                  ),
                if (wide) Container(width: 1, color: line),
                if (wide || !showList)
                  Expanded(
                    child: Column(
                      children: [
                        if (c.error != null)
                          ErrorStrip(
                            message: c.error!,
                            onDismiss: c.dismissError,
                          ),
                        if (!c.connected) _connectionBanner(),
                        if (c.incoming != null)
                          IncomingCallBanner(controller: c),
                        if (c.selected == null)
                          Expanded(child: _welcome())
                        else
                          Expanded(
                            child: ConversationView(
                              key: ValueKey(c.selected!.id),
                              controller: c,
                              onBack: wide ? null : () => c.select(null),
                              onInfo: () => _info(c.selected!),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _rail() => Container(
    width: 76,
    color: night,
    child: Column(
      children: [
        const SizedBox(height: 28),
        const BrandMark(size: 40),
        const SizedBox(height: 42),
        IconButton.filled(
          onPressed: () => c.select(null),
          tooltip: 'Розмови',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF39344F),
            foregroundColor: const Color(0xFFC3B9FF),
            fixedSize: const Size(46, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
        ),
        const SizedBox(height: 16),
        IconButton(
          onPressed: _newChat,
          tooltip: 'Нова розмова',
          color: const Color(0xFF989BB4),
          icon: const Icon(Icons.add_comment_outlined, size: 22),
        ),
        const Spacer(),
        IconButton(
          onPressed: _settings,
          tooltip: 'Акаунт і сервер',
          color: const Color(0xFF989BB4),
          icon: const Icon(Icons.tune_rounded, size: 22),
        ),
        const SizedBox(height: 18),
        Tooltip(
          message: c.me!.name,
          child: Avatar(name: c.me!.name, size: 38),
        ),
        const SizedBox(height: 26),
      ],
    ),
  );

  Widget _sidebar(bool wide, bool rail) {
    final chats = c.chats
        .where(
          (chat) =>
              (!_unreadOnly || chat.unread > 0) &&
              chat.name.toLowerCase().contains(_filter.toLowerCase()),
        )
        .toList();
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 16, 0),
            child: Row(
              children: [
                if (!rail) ...[
                  const BrandMark(size: 32),
                  const SizedBox(width: 10),
                ],
                Text('Розмови', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: _newChat,
                  tooltip: 'Нова розмова',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1EEFF),
                    foregroundColor: violet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_square, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 7, 24, 24),
            child: Text(
              'Добре, коли свої поруч.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (s) => setState(() => _filter = s),
              decoration: const InputDecoration(
                hintText: 'Пошук розмов',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                _filterChip(
                  'Усі',
                  !_unreadOnly,
                  () => setState(() => _unreadOnly = false),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Непрочитані',
                  _unreadOnly,
                  () => setState(() => _unreadOnly = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!wide && c.error != null)
            ErrorStrip(message: c.error!, onDismiss: c.dismissError),
          if (!wide && !c.connected) _connectionBanner(),
          if (!wide && c.incoming != null) IncomingCallBanner(controller: c),
          Expanded(
            child: chats.isEmpty
                ? _emptyList()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: chats.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _chatTile(chats[i]),
                  ),
          ),
          if (!wide && c.calls.active)
            TextButton.icon(
              onPressed: () =>
                  c.select(c.calls.room?.chatId ?? c.calls.joiningChat),
              icon: const Icon(Icons.call_rounded, color: mint),
              label: const Text('Повернутися до дзвінка'),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: line)),
            ),
            child: Row(
              children: [
                Avatar(name: c.me!.name, size: 37),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.me!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: c.connected ? mint : mutedInk,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            c.connected ? 'На зв’язку' : 'Підключення…',
                            style: const TextStyle(
                              color: mutedInk,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _settings,
                  tooltip: 'Акаунт і сервер',
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback action) =>
      InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0EDFC) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? violet : mutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  Widget _chatTile(Conversation chat) {
    final selected = chat.id == c.selectedId;
    final last = chat.lastMessage;
    final typing = c.typingLabel(chat.id);
    return Material(
      color: selected ? const Color(0xFFF0EDFC) : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => c.select(chat.id),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Avatar(
                name: chat.name,
                group: chat.isGroup,
                online:
                    !chat.isGroup &&
                    chat.members.any((u) => u.id != c.me!.id && u.online),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: chat.unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          last == null ? '' : timeLabel(last.createdAt),
                          style: const TextStyle(fontSize: 10, color: mutedInk),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.call != null
                                ? 'Дзвінок триває'
                                : typing.isNotEmpty
                                ? typing
                                : last == null
                                ? 'Почніть розмову'
                                : '${last.senderId == c.me!.id ? 'Ви: ' : ''}${last.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: chat.call != null
                                  ? mint
                                  : typing.isNotEmpty
                                  ? violet
                                  : mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (chat.unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: violet,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              chat.unread > 99 ? '99+' : '${chat.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyList() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, color: Color(0xFFC6BEE7), size: 40),
          const SizedBox(height: 18),
          Text(
            c.chats.isEmpty
                ? 'Тут починається спілкування'
                : 'Розмов не знайдено',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            c.chats.isEmpty
                ? 'Знайдіть друга за логіном або\nзберіть своїх у групі.'
                : 'Спробуйте інший пошук або фільтр.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedInk, fontSize: 12, height: 1.6),
          ),
          if (c.chats.isEmpty) ...[
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _newChat,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Нова розмова'),
            ),
          ],
        ],
      ),
    ),
  );
  Widget _welcome() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEAFB),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const BrandMark(size: 78),
          ),
          const SizedBox(height: 30),
          Text(
            'Ближче, ніж здається',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Оберіть розмову зліва або почніть нову.\nІноді одне «привіт» змінює весь день.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedInk, height: 1.8),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _newChat,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Почати розмову'),
          ),
          const SizedBox(height: 56),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              _Feature(icon: Icons.bolt_rounded, text: 'Живе спілкування'),
              _Feature(
                icon: Icons.headset_mic_outlined,
                text: 'Групові дзвінки',
              ),
              _Feature(icon: Icons.devices_rounded, text: 'На всіх пристроях'),
            ],
          ),
          if (c.calls.active)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CallPanel(controller: c),
            ),
        ],
      ),
    ),
  );
  Widget _connectionBanner() => Container(
    width: double.infinity,
    color: const Color(0xFFFFF7E4),
    padding: const EdgeInsets.all(10),
    child: const Text(
      'Відновлюємо з’єднання з сервером…',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF9A8143), fontSize: 11),
    ),
  );
  void _info(Conversation chat) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(chat.name),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              chat.isGroup
                  ? '${chat.members.length} учасників · до 8 у дзвінку'
                  : 'Учасники розмови',
              style: const TextStyle(color: mutedInk, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...chat.members.map(
              (u) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: u.name, online: u.online, size: 38),
                title: Text(u.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  '@${u.username}',
                  style: const TextStyle(fontSize: 12, color: mutedInk),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    ),
  );
  void _settings() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ваш простір'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(name: c.me!.name),
              title: Text(c.me!.name),
              subtitle: Text('@${c.me!.username}'),
            ),
            const SizedBox(height: 20),
            const Text(
              'СЕРВЕР',
              style: TextStyle(
                fontSize: 10,
                color: mutedInk,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(c.api.server, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            const Text(
              'Вхідні дзвінки доступні, поки застосунок відкритий. Для зміни сервера вийдіть з акаунта.',
              style: TextStyle(color: mutedInk, fontSize: 12, height: 1.6),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрити'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            c.logout();
          },
          child: const Text(
            'Вийти з акаунта',
            style: TextStyle(color: Color(0xFFC56E80)),
          ),
        ),
      ],
    ),
  );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: const Color(0xFFAAA0CF)),
      const SizedBox(width: 7),
      Text(text, style: const TextStyle(color: mutedInk, fontSize: 11)),
    ],
  );
}

class ConversationView extends StatefulWidget {
  final ChatController controller;
  final VoidCallback? onBack;
  final VoidCallback onInfo;
  const ConversationView({
    super.key,
    required this.controller,
    this.onBack,
    required this.onInfo,
  });
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _text = TextEditingController(), _scroll = ScrollController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _nonce, _pendingText;
  int _lastCount = -1;
  DateTime _lastTyping = DateTime(2000);
  ChatController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _text.text = c.drafts[c.selectedId] ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim(), chat = c.selected;
    if (text.isEmpty || _sending || chat == null) return;
    if (text.runes.length > 4000) {
      c.showError('Повідомлення може містити до 4000 символів');
      return;
    }
    if (_pendingText != text) {
      _pendingText = text;
      _nonce =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    setState(() => _sending = true);
    final success = await c.sendMessage(chat.id, text, _nonce!);
    if (!mounted) return;
    setState(() => _sending = false);
    if (success) {
      if (_text.text.trim() == text) {
        _text.clear();
        c.drafts.remove(chat.id);
      }
      _nonce = null;
      _pendingText = null;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _content(context, constraints.maxHeight < 600),
  );

  Widget _content(BuildContext context, bool compactCall) {
    final chat = c.selected!;
    final messages = c.history[chat.id] ?? [];
    final typing = c.typingLabel(chat.id);
    if (messages.length != _lastCount) {
      final shouldScroll = _scroll.hasClients && _scroll.offset < 100;
      _lastCount = messages.length;
      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
    return Column(
      children: [
        Container(
          height: 90,
          padding: EdgeInsets.symmetric(
            horizontal: widget.onBack == null ? 28 : 8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  onPressed: widget.onBack,
                  tooltip: 'До розмов',
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                ),
              Avatar(name: chat.name, group: chat.isGroup, size: 44),
              const SizedBox(width: 13),
              Expanded(
                child: InkWell(
                  onTap: widget.onInfo,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        typing.isEmpty ? chat.subtitle(c.me!.id) : typing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: typing.isNotEmpty ? violet : mutedInk,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: c.calls.active || !c.connected
                    ? null
                    : () => c.startCall(chat),
                tooltip: chat.call == null
                    ? 'Аудіодзвінок'
                    : 'Приєднатися до дзвінка',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEFEBFC),
                  foregroundColor: violet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  fixedSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.call_outlined, size: 21),
              ),
              IconButton(
                onPressed: widget.onInfo,
                tooltip: 'Учасники',
                icon: const Icon(Icons.more_vert_rounded, size: 22),
              ),
            ],
          ),
        ),
        if (chat.call != null && !c.calls.active)
          Container(
            color: const Color(0xFFE9F5EE),
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, color: mint, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Дзвінок триває', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: c.connected ? () => c.startCall(chat) : null,
                  child: const Text('Приєднатися'),
                ),
              ],
            ),
          ),
        if (c.calls.active)
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .43,
              ),
              child: SingleChildScrollView(
                child: CallPanel(controller: c, compact: compactCall),
              ),
            ),
          ),
        Expanded(
          child: c.loadingHistory.contains(chat.id) && messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Avatar(name: chat.name, group: chat.isGroup, size: 72),
                        const SizedBox(height: 20),
                        Text(
                          'Скажіть «привіт»',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          chat.isGroup
                              ? 'Це початок вашої спільної історії.'
                              : 'Ваша розмова з ${chat.name} починається тут.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: mutedInk, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  itemCount:
                      messages.length + (c.hasOlder.contains(chat.id) ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == messages.length) {
                      return Center(
                        child: TextButton(
                          onPressed: c.loadingHistory.contains(chat.id)
                              ? null
                              : () => c.loadMessages(chat.id, older: true),
                          child: Text(
                            c.loadingHistory.contains(chat.id)
                                ? 'Завантаження…'
                                : 'Попередні повідомлення',
                          ),
                        ),
                      );
                    }
                    final i = messages.length - 1 - index,
                        message = messages[i];
                    final newDay =
                        i == 0 ||
                        !_sameDay(messages[i - 1].createdAt, message.createdAt);
                    return Column(
                      children: [
                        if (newDay)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBEDF4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dateLabel(message.createdAt),
                                style: const TextStyle(
                                  color: mutedInk,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        _bubble(message, chat),
                      ],
                    );
                  },
                ),
        ),
        _composer(chat),
      ],
    );
  }

  Widget _bubble(ChatMessage message, Conversation chat) {
    final mine = message.senderId == c.me!.id;
    ChatUser? sender;
    for (final u in chat.members) {
      if (u.id == message.senderId) sender = u;
    }
    final read = chat.readIds.entries.any(
      (e) => e.key != c.me!.id && e.value >= message.id,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width < 840
                ? MediaQuery.sizeOf(context).width * .76
                : 470,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!mine && chat.isGroup)
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 5),
                  child: Text(
                    sender?.name ?? 'Учасник',
                    style: const TextStyle(color: mutedInk, fontSize: 10),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: mine ? violet : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(17),
                    topRight: const Radius.circular(17),
                    bottomLeft: Radius.circular(mine ? 17 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 17),
                  ),
                  border: mine ? null : Border.all(color: line),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    color: mine ? Colors.white : ink,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel(message.createdAt, onlyTime: true),
                    style: const TextStyle(color: mutedInk, fontSize: 9),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: read ? 'Прочитано' : 'Збережено на сервері',
                      child: Icon(
                        read ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: read ? violet : mutedInk,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(Conversation chat) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed &&
                  !(_text.value.composing.isValid &&
                      !_text.value.composing.isCollapsed)) {
                _send();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _text,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              onChanged: (_) {
                c.drafts[chat.id] = _text.text;
                if (DateTime.now().difference(_lastTyping).inSeconds >= 2) {
                  _lastTyping = DateTime.now();
                  c.sendEvent({'type': 'typing', 'chat_id': chat.id});
                }
              },
              decoration: const InputDecoration(
                hintText: 'Напишіть повідомлення…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: _sending ? null : _send,
          tooltip: 'Надіслати · Enter',
          style: IconButton.styleFrom(
            backgroundColor: violet,
            foregroundColor: Colors.white,
            fixedSize: const Size(46, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_upward_rounded, size: 22),
        ),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String timeLabel(DateTime d, {bool onlyTime = false}) {
  if (onlyTime || _sameDay(d, DateTime.now())) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

String dateLabel(DateTime d) {
  if (_sameDay(d, DateTime.now())) return 'Сьогодні';
  if (_sameDay(d, DateTime.now().subtract(const Duration(days: 1)))) {
    return 'Учора';
  }
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
