import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'call_service.dart';
import 'models.dart';

class ChatController extends ChangeNotifier {
  final ChatApi api;
  final FlutterSecureStorage storage;
  late final CallService calls;
  ChatController({ChatApi? api, FlutterSecureStorage? storage})
    : api = api ?? ChatApi(),
      storage = storage ?? const FlutterSecureStorage() {
    calls = CallService(
      api: this.api,
      send: sendEvent,
      myId: () => me?.id ?? '',
      onError: showError,
    )..addListener(_notify);
  }
  ChatUser? me;
  bool booting = true, busy = false, connected = false;
  String? error, selectedId;
  List<Conversation> chats = [];
  final Map<String, List<ChatMessage>> history = {};
  final Map<String, String> drafts = {};
  bool foreground = true;
  final Set<String> loadingHistory = {}, hasOlder = {};
  final Map<String, Map<String, DateTime>> typing = {};
  CallRoom? incoming;
  WebSocket? _socket;
  Timer? _retry, _refresh, _ring;
  int _retries = 0, _generation = 0, _connectionEpoch = 0;
  bool _connecting = false, _disposed = false;
  Future<void> _events = Future.value();
  Conversation? get selected => conversation(selectedId);
  Conversation? conversation(String? id) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void showError(String message) {
    error = message;
    _notify();
  }

  void dismissError() {
    error = null;
    _notify();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      api.server =
          prefs.getString('server') ??
          const String.fromEnvironment(
            'SPAYR_SERVER',
            defaultValue: 'http://localhost:8080',
          );
      final saved = await storage.read(key: 'spayr_session');
      if (saved != null) {
        final data = jsonDecode(saved);
        if (data['server'] == api.server) {
          api.token = data['token'];
          me = ChatUser.fromJson(await api.request('GET', '/api/me'));
          await refreshChats();
          unawaited(connect());
        }
      }
    } catch (e) {
      if (e is ApiException && e.status == 401) {
        await storage.delete(key: 'spayr_session');
      }
      api.token = null;
      me = null;
      error = e is ApiException
          ? e.message
          : 'Не вдалося відновити сесію. Увійдіть знову.';
    } finally {
      booting = false;
      _notify();
    }
  }

  Future<void> authenticate({
    required String server,
    required String username,
    required String password,
    required String name,
    required bool register,
  }) async {
    busy = true;
    error = null;
    _notify();
    try {
      api.server = ChatApi.normalizeServer(server);
      api.token = null;
      final data = await api.request(
        'POST',
        '/api/auth/${register ? 'register' : 'login'}',
        {'username': username, 'password': password, 'name': name},
      );
      api.token = data['token'];
      try {
        await storage.write(
          key: 'spayr_session',
          value: jsonEncode({'server': api.server, 'token': api.token}),
        );
      } catch (_) {
        error = 'Вхід успішний, але пристрій не дозволив зберегти сесію.';
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server', api.server);
      me = ChatUser.fromJson(data['user']);
      await refreshChats();
      unawaited(connect());
    } catch (e) {
      showError(
        e is ApiException ? e.message : 'Не вдалося увійти. Спробуйте ще раз.',
      );
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> connect() async {
    if (_disposed ||
        me == null ||
        _connecting ||
        connected ||
        _socket != null) {
      return;
    }
    _connecting = true;
    final generation = _generation;
    final connection = ++_connectionEpoch;
    try {
      final socket = await api.connect();
      if (generation != _generation ||
          connection != _connectionEpoch ||
          _disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.listen(
        (raw) {
          _events = _events
              .then((_) async {
                if (generation == _generation &&
                    connection == _connectionEpoch) {
                  await _handle(
                    Map<String, dynamic>.from(jsonDecode(raw as String)),
                  );
                }
              })
              .catchError((Object e) {
                if (generation == _generation &&
                    connection == _connectionEpoch) {
                  showError(
                    e is ApiException
                        ? e.message
                        : 'Не вдалося обробити подію дзвінка. Спробуйте приєднатися знову.',
                  );
                }
              });
        },
        onDone: () => _disconnected(generation, connection),
        onError: (_) => _disconnected(generation, connection),
        cancelOnError: true,
      );
    } catch (_) {
      _disconnected(generation, connection);
    } finally {
      _connecting = false;
    }
  }

  void _disconnected(int generation, int connection) {
    if (generation != _generation ||
        connection != _connectionEpoch ||
        _disposed) {
      return;
    }
    ++_connectionEpoch;
    final hadCall = calls.active;
    connected = false;
    final old = _socket;
    _socket = null;
    unawaited(old?.close());
    unawaited(calls.clear());
    _clearIncoming();
    if (hadCall) {
      error =
          'З’єднання втрачено. Приєднайтеся до дзвінка після відновлення мережі.';
    }
    _notify();
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (generation != _generation || _disposed || connected) return;
    _retry?.cancel();
    if (me != null) {
      final seconds = [1, 2, 4, 8, 15, 30][_retries.clamp(0, 5)];
      _retries++;
      _retry = Timer(Duration(seconds: seconds), () async {
        try {
          await api.request('GET', '/api/me');
          await connect();
        } on ApiException catch (e) {
          if (e.status == 401) {
            await logout(remote: false);
            showError(e.message);
          } else {
            _scheduleReconnect(generation);
          }
        }
      });
    }
  }

  void resume() {
    foreground = true;
    if (!connected) {
      _retry?.cancel();
      unawaited(connect());
    } else {
      unawaited(refreshChats());
    }
    if (selectedId != null) unawaited(markRead(selectedId!));
  }

  void sendEvent(Json event) {
    if (_socket == null || !connected) {
      if (event['type'] == 'call.join') {
        throw ApiException('Зачекайте відновлення з’єднання');
      }
      return;
    }
    _socket!.add(jsonEncode(event));
  }

  Future<void> _handle(Json event) async {
    final type = event['type'];
    if (type == 'ready') {
      connected = true;
      _retries = 0;
      _retry?.cancel();
      await refreshChats();
      if (selectedId != null) await loadMessages(selectedId!);
    } else if (type == 'message') {
      final m = ChatMessage.fromJson(event['message']);
      _merge(m.chatId, [m]);
      _scheduleRefresh();
      if (selectedId == m.chatId) unawaited(markRead(m.chatId));
    } else if (type == 'chats.changed') {
      _scheduleRefresh();
    } else if (type == 'presence') {
      for (final chat in chats) {
        for (final u in chat.members) {
          if (u.id == event['user_id']) u.online = event['online'];
        }
      }
    } else if (type == 'read') {
      final chat = conversation(event['chat_id']);
      if (chat != null) {
        final userId = event['user_id'] as String;
        final value = event['id'] as int;
        if (value > (chat.readIds[userId] ?? 0)) chat.readIds[userId] = value;
        if (userId == me?.id) chat.unread = 0;
      }
    } else if (type == 'typing' && event['user_id'] != me?.id) {
      final chat = event['chat_id'] as String;
      (typing[chat] ??= {})[event['user_id']] = DateTime.now();
      Future.delayed(const Duration(seconds: 4), _notify);
    } else if (type == 'call.invite') {
      final call = CallRoom.fromJson(event['call']);
      if (event['from']['id'] != me?.id && !calls.active && incoming == null) {
        incoming = call;
        unawaited(SystemSound.play(SystemSoundType.alert));
        _ring?.cancel();
        _ring = Timer.periodic(
          const Duration(seconds: 4),
          (_) => SystemSound.play(SystemSoundType.alert),
        );
      }
      conversation(call.chatId)?.call = call;
    } else if (type == 'call.state') {
      final call = CallRoom.fromJson(event['call']);
      conversation(call.chatId)?.call = call;
      if (incoming?.id == call.id) incoming = call;
    } else if (type == 'call.ended') {
      final chat = conversation(event['chat_id']);
      if (chat?.call?.id == event['call_id']) chat?.call = null;
      if (incoming?.id == event['call_id']) _clearIncoming();
    } else if (type == 'error' && calls.joiningChat == null) {
      showError(event['error']);
    }
    await calls.handle(event);
    _notify();
  }

  void _scheduleRefresh() {
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 180), refreshChats);
  }

  Future<void> refreshChats() async {
    final generation = _generation;
    try {
      final data = await api.request('GET', '/api/chats') as List;
      if (generation != _generation || me == null) return;
      chats = data.map((j) => Conversation.fromJson(j)).toList();
      _notify();
    } on ApiException catch (e) {
      if (e.status == 401) {
        await logout(remote: false);
      }
      showError(e.message);
    }
  }

  void _merge(String chatId, List<ChatMessage> messages) {
    final all = {for (final m in history[chatId] ?? <ChatMessage>[]) m.id: m};
    for (final m in messages) {
      all[m.id] = m;
    }
    history[chatId] = all.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> select(String? id) async {
    selectedId = id;
    _notify();
    if (id != null) {
      await loadMessages(id);
      await markRead(id);
    }
  }

  Future<void> loadMessages(String id, {bool older = false}) async {
    if (loadingHistory.contains(id)) return;
    final generation = _generation;
    loadingHistory.add(id);
    _notify();
    try {
      final existing = history[id] ?? [];
      final query = older && existing.isNotEmpty
          ? '?before=${existing.first.id}'
          : '';
      final data =
          await api.request('GET', '/api/chats/$id/messages$query') as List;
      if (generation != _generation) return;
      final messages = data.map((m) => ChatMessage.fromJson(m)).toList();
      // After a long outage, keep a contiguous latest page; older messages remain
      // reachable through pagination instead of hiding a gap in cached history.
      final gap =
          !older &&
          existing.isNotEmpty &&
          messages.length == 50 &&
          messages.first.id > existing.last.id;
      if (gap) history[id] = [];
      _merge(id, messages);
      if (older || existing.isEmpty || gap) {
        if (messages.length == 50) {
          hasOlder.add(id);
        } else {
          hasOlder.remove(id);
        }
      }
    } on ApiException catch (e) {
      showError(e.message);
    } finally {
      loadingHistory.remove(id);
      _notify();
    }
  }

  Future<void> markRead(String id) async {
    if (!foreground || selectedId != id) return;
    final messages = history[id];
    if (messages == null || messages.isEmpty) return;
    final last = messages.last.id;
    if ((conversation(id)?.readIds[me?.id] ?? 0) >= last) return;
    try {
      await api.request('POST', '/api/chats/$id/read', {'id': last});
      final chat = conversation(id);
      if (chat != null && me != null) {
        chat.readIds[me!.id] = last;
        chat.unread = 0;
      }
      _notify();
    } catch (_) {
      /* Retry on the next message or chat selection. */
    }
  }

  Future<bool> sendMessage(String id, String text, String nonce) async {
    final generation = _generation;
    try {
      final data = await api.request('POST', '/api/chats/$id/messages', {
        'text': text,
        'nonce': nonce,
      });
      if (generation != _generation) return false;
      _merge(id, [ChatMessage.fromJson(data)]);
      _scheduleRefresh();
      _notify();
      return true;
    } on ApiException catch (e) {
      showError(e.message);
      return false;
    }
  }

  Future<List<ChatUser>> searchUsers(String query) async {
    final data =
        await api.request(
              'GET',
              '/api/users?q=${Uri.encodeQueryComponent(query)}',
            )
            as List;
    return data.map((u) => ChatUser.fromJson(u)).toList();
  }

  Future<void> createChat(List<String> ids, String name, bool group) async {
    final data = await api.request('POST', '/api/chats', {
      'members': ids,
      'name': name,
      'is_group': group,
    });
    await refreshChats();
    await select(data['id']);
  }

  Future<void> startCall(Conversation chat) async {
    if (!connected) {
      showError('Зачекайте підключення до сервера');
      return;
    }
    if (calls.active) {
      showError('Спочатку завершіть поточний дзвінок');
      return;
    }
    if (incoming?.chatId == chat.id) _clearIncoming();
    await calls.join(chat.id, callId: chat.call?.id);
  }

  Future<void> acceptCall() async {
    final call = incoming;
    if (call == null) return;
    _clearIncoming();
    _notify();
    unawaited(select(call.chatId));
    await calls.join(call.chatId, callId: call.id);
  }

  void declineCall() {
    final call = incoming;
    if (call != null) {
      sendEvent({
        'type': 'call.decline',
        'chat_id': call.chatId,
        'call_id': call.id,
      });
    }
    _clearIncoming();
    _notify();
  }

  void _clearIncoming() {
    incoming = null;
    _ring?.cancel();
    _ring = null;
  }

  String typingLabel(String chatId) {
    final users = typing[chatId] ?? {};
    final active = users.entries
        .where((e) => DateTime.now().difference(e.value).inSeconds < 4)
        .map((e) => e.key)
        .toSet();
    if (active.isEmpty) return '';
    final names =
        conversation(chatId)?.members
            .where((u) => active.contains(u.id))
            .map((u) => u.name)
            .toList() ??
        [];
    return names.isEmpty
        ? ''
        : '${names.join(', ')} ${names.length == 1 ? 'пише' : 'пишуть'}…';
  }

  Future<void> logout({bool remote = true}) async {
    await calls.hangUp();
    ++_generation;
    _retry?.cancel();
    _refresh?.cancel();
    _clearIncoming();
    final socket = _socket;
    _socket = null;
    connected = false;
    await socket?.close();
    if (remote) {
      try {
        await api.request('POST', '/api/auth/logout');
      } catch (_) {
        /* Local logout still removes the device session. */
      }
    }
    await storage.delete(key: 'spayr_session');
    api.token = null;
    me = null;
    selectedId = null;
    chats = [];
    history.clear();
    drafts.clear();
    hasOlder.clear();
    typing.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _retry?.cancel();
    _refresh?.cancel();
    _ring?.cancel();
    unawaited(_socket?.close());
    calls.removeListener(_notify);
    calls.dispose();
    api.dispose();
    super.dispose();
  }
}
