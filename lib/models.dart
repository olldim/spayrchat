typedef Json = Map<String, dynamic>;

class ChatUser {
  final String id, username, name;
  bool online;
  ChatUser({
    required this.id,
    required this.username,
    required this.name,
    this.online = false,
  });
  factory ChatUser.fromJson(Json j) => ChatUser(
    id: j['id'],
    username: j['username'],
    name: j['name'],
    online: j['online'] == true,
  );
  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((s) => s.isEmpty ? '' : s.substring(0, 1).toUpperCase())
      .join();
}

class ChatMessage {
  final int id;
  final String chatId, senderId, text, nonce;
  final DateTime createdAt;
  ChatMessage.fromJson(Json j)
    : id = j['id'],
      chatId = j['chat_id'],
      senderId = j['sender_id'],
      text = j['text'],
      nonce = j['nonce'],
      createdAt = DateTime.fromMillisecondsSinceEpoch(j['created_at']);
}

class Conversation {
  final String id, name;
  final bool isGroup;
  final List<ChatUser> members;
  final Map<String, int> readIds;
  ChatMessage? lastMessage;
  int unread;
  CallRoom? call;
  Conversation.fromJson(Json j)
    : id = j['id'],
      name = j['name'],
      isGroup = j['is_group'],
      members = (j['members'] as List)
          .map((u) => ChatUser.fromJson(u))
          .toList(),
      readIds = Map<String, int>.from(j['read_ids'] ?? {}),
      lastMessage = j['last_message'] == null
          ? null
          : ChatMessage.fromJson(j['last_message']),
      unread = j['unread'] ?? 0,
      call = j['call'] == null ? null : CallRoom.fromJson(j['call']);
  String subtitle(String me) => isGroup
      ? '${members.length} учасників'
      : (members.where((u) => u.id != me).any((u) => u.online)
            ? 'У мережі'
            : 'Не в мережі');
}

class CallParticipant {
  final ChatUser user;
  final bool muted;
  CallParticipant.fromJson(Json j)
    : user = ChatUser.fromJson(j['user']),
      muted = j['muted'] == true;
}

class CallRoom {
  final String id, chatId;
  final DateTime startedAt;
  final List<CallParticipant> participants;
  CallRoom.fromJson(Json j)
    : id = j['id'],
      chatId = j['chat_id'],
      startedAt = DateTime.fromMillisecondsSinceEpoch(j['started_at']),
      participants = (j['participants'] as List)
          .map((p) => CallParticipant.fromJson(p))
          .toList();
}
