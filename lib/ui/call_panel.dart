import 'dart:async';
import 'package:flutter/material.dart';
import '../chat_controller.dart';
import 'theme.dart';

class CallPanel extends StatefulWidget {
  final ChatController controller;
  final bool compact;
  const CallPanel({super.key, required this.controller, this.compact = false});
  @override
  State<CallPanel> createState() => _CallPanelState();
}

class _CallPanelState extends State<CallPanel> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, call = c.calls, room = call.room;
    final chat = c.conversation(room?.chatId ?? call.joiningChat);
    final duration = room == null
        ? Duration.zero
        : DateTime.now().difference(room.startedAt);
    final time =
        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    final compact =
        widget.compact ||
        MediaQuery.sizeOf(context).height < 600 ||
        View.of(context).viewInsets.bottom > 0;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _control(
          icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: call.muted ? 'Увімкнути мікрофон' : 'Вимкнути мікрофон',
          onTap: room == null ? null : call.toggleMute,
          color: const Color(0xFF49425F),
        ),
        if (call.mobile && !compact) ...[
          const SizedBox(width: 12),
          _control(
            icon: call.speaker
                ? Icons.volume_up_rounded
                : Icons.hearing_rounded,
            label: call.speaker ? 'Динамік телефона' : 'Гучний зв’язок',
            onTap: call.toggleSpeaker,
            color: const Color(0xFF49425F),
          ),
        ],
        const SizedBox(width: 12),
        _control(
          icon: Icons.call_end_rounded,
          label: 'Завершити дзвінок',
          onTap: call.hangUp,
          color: const Color(0xFFE57787),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26253F), Color(0xFF383153)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: compact
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    '${chat?.name ?? 'Дзвінок'} · $time',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                controls,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: mint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      room == null ? 'ПІДКЛЮЧЕННЯ' : 'АУДІОДЗВІНОК',
                      style: const TextStyle(
                        color: Color(0xFFBEB8DC),
                        fontSize: 9,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFFBEB8DC),
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  chat?.name ?? 'Ваша розмова',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room == null
                      ? 'Готуємо мікрофон…'
                      : room.participants.length < 2
                      ? 'Очікуємо на відповідь…'
                      : 'Учасників: ${room.participants.length} · ${call.roundTripMs == null ? 'WebRTC' : 'RTT ${call.roundTripMs} мс'}',
                  style: const TextStyle(
                    color: Color(0xFFB3ACC9),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                if (room != null)
                  SizedBox(
                    height: 112,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: room.participants.map((p) {
                          final self = p.user.id == c.me!.id,
                              muted = p.user.id == c.me!.id
                                  ? call.muted
                                  : p.muted;
                          return SizedBox(
                            width: 90,
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: muted
                                              ? Colors.white12
                                              : const Color(0xFF8274B0),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Avatar(
                                        name: p.user.name,
                                        size: 44,
                                      ),
                                    ),
                                    Positioned(
                                      right: -3,
                                      bottom: -1,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: muted
                                              ? const Color(0xFFB47083)
                                              : const Color(0xFF548D7D),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          muted
                                              ? Icons.mic_off_rounded
                                              : Icons.mic_rounded,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  self ? 'Ви' : p.user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  self
                                      ? (muted
                                            ? 'Мікрофон вимкнено'
                                            : 'Мікрофон увімкнено')
                                      : (call.peers[p.user.id]?.status ??
                                            'З’єднання…'),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: Color(0xFFB3ACC9),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                controls,
              ],
            ),
    );
  }

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) => Tooltip(
    message: label,
    child: IconButton.filled(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 21),
    ),
  );
}

class IncomingCallBanner extends StatelessWidget {
  final ChatController controller;
  const IncomingCallBanner({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final room = controller.incoming!;
    final name =
        controller.conversation(room.chatId)?.name ??
        'Р’С…С–РґРЅРёР№ РґР·РІС–РЅРѕРє';
    return Container(
      color: const Color(0xFFEEEAFD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.ring_volume_rounded, color: violet),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Р’С…С–РґРЅРёР№ Р°СѓРґС–РѕРґР·РІС–РЅРѕРє',
                  style: TextStyle(fontSize: 11, color: mutedInk),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: controller.declineCall,
            tooltip: 'Р’С–РґС…РёР»РёС‚Рё',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF9DAE1),
              foregroundColor: const Color(0xFFC5687C),
            ),
            icon: const Icon(Icons.call_end_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: controller.acceptCall,
            tooltip: 'Р’С–РґРїРѕРІС–СЃС‚Рё',
            style: IconButton.styleFrom(
              backgroundColor: mint,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call_rounded),
          ),
        ],
      ),
    );
  }
}
