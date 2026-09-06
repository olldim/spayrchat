import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api.dart';
import 'models.dart';

class AudioPeer {
  final RTCPeerConnection connection;
  final RTCVideoRenderer renderer;
  final List<RTCIceCandidate> candidates = [];
  bool hasRemoteDescription = false;
  String status = 'З’єднання…';
  AudioPeer(this.connection, this.renderer);
}

class CallService extends ChangeNotifier {
  final ChatApi api;
  final void Function(Json) send;
  final String Function() myId;
  final void Function(String) onError;
  CallService({
    required this.api,
    required this.send,
    required this.myId,
    required this.onError,
  });
  CallRoom? room;
  String? joiningChat;
  final Map<String, AudioPeer> peers = {};
  MediaStream? _local;
  List<dynamic> _iceServers = [];
  Completer<void>? _joined;
  bool muted = false, speaker = false, turnEnabled = false;
  int? roundTripMs;
  int _epoch = 0;
  Timer? _stats;
  bool _disposed = false;
  bool get active => room != null || joiningChat != null;
  bool get mobile => Platform.isAndroid || Platform.isIOS;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> join(String chatId, {String? callId}) async {
    if (active) return;
    joiningChat = chatId;
    final epoch = ++_epoch;
    _notify();
    try {
      final ice = await api.request('GET', '/api/ice');
      if (epoch != _epoch) return;
      _iceServers = ice['iceServers'];
      turnEnabled = ice['turnEnabled'] == true;
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
        },
        'video': false,
      });
      if (epoch != _epoch) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        return;
      }
      _local = stream;
      muted = false;
      speaker = false;
      if (mobile) await Helper.setSpeakerphoneOn(false);
      _joined = Completer<void>();
      send({'type': 'call.join', 'chat_id': chatId, 'call_id': ?callId});
      await _joined!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw ApiException('Не вдалося приєднатися до дзвінка'),
      );
      if (epoch == _epoch) {
        _stats = Timer.periodic(
          const Duration(seconds: 4),
          (_) => _refreshStats(),
        );
      }
    } catch (e) {
      if (epoch == _epoch) {
        await hangUp();
        onError(
          e is ApiException
              ? e.message
              : 'Не вдалося почати дзвінок. Перевірте дозвіл на мікрофон та аудіопристрій.',
        );
      }
    }
  }

  Future<AudioPeer> _peer(String id) async {
    if (peers[id] != null) return peers[id]!;
    final current = room!;
    final epoch = _epoch;
    final pc = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
    });
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    if (epoch != _epoch) {
      await pc.close();
      await renderer.dispose();
      throw ApiException('Дзвінок завершено');
    }
    final peer = AudioPeer(pc, renderer);
    peers[id] = peer;
    for (final track in _local!.getAudioTracks()) {
      await pc.addTrack(track, _local!);
    }
    pc.onIceCandidate = (candidate) {
      if (epoch == _epoch && candidate.candidate != null) {
        send({
          'type': 'signal',
          'chat_id': current.chatId,
          'call_id': current.id,
          'to': id,
          'data': {'candidate': candidate.toMap()},
        });
      }
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty && epoch == _epoch) {
        renderer.srcObject = event.streams.first;
      }
    };
    pc.onConnectionState = (state) {
      if (epoch != _epoch) return;
      peer.status = switch (state) {
        RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'На зв’язку',
        RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
          'Немає аудіоз’єднання',
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
          'Відновлення…',
        _ => 'З’єднання…',
      };
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onError(
          'Не вдалося з’єднати аудіо. Перевірте TURN на сервері або приєднайтеся знову.',
        );
      }
      _notify();
    };
    return peer;
  }

  String _voiceSDP(String sdp) {
    // Opus keeps audio packets small. No recording, transcoding or media HTTP requests.
    return sdp.replaceAllMapped(
      RegExp(r'a=fmtp:(\d+) ([^\r\n]*useinbandfec=1[^\r\n]*)'),
      (m) {
        final params = m[2]!
            .replaceAll(RegExp(r';?\s*minptime=\d+'), '')
            .replaceAll(RegExp(r';?\s*stereo=\d+'), '');
        return 'a=fmtp:${m[1]} $params;minptime=10;stereo=0;maxaveragebitrate=32000';
      },
    );
  }

  Future<void> handle(Json event) async {
    final type = event['type'];
    if (type == 'call.joined') {
      final next = CallRoom.fromJson(event['call']);
      if (joiningChat != next.chatId || _local == null) {
        send({
          'type': 'call.leave',
          'chat_id': next.chatId,
          'call_id': next.id,
        });
        return;
      }
      room = next;
      joiningChat = null;
      if (_joined?.isCompleted == false) _joined!.complete();
      _notify();
      for (final u in event['peers'] as List) {
        if (room?.id != next.id) return;
        final peer = await _peer(u['id']);
        final offer = await peer.connection.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false,
        });
        final description = RTCSessionDescription(
          _voiceSDP(offer.sdp!),
          offer.type,
        );
        await peer.connection.setLocalDescription(description);
        if (room?.id != next.id) return;
        send({
          'type': 'signal',
          'chat_id': next.chatId,
          'call_id': next.id,
          'to': u['id'],
          'data': {'description': description.toMap()},
        });
      }
      return;
    }
    if (type == 'error' && joiningChat != null) {
      if (_joined?.isCompleted == false) {
        _joined!.completeError(ApiException(event['error']));
      }
      return;
    }
    if (room == null) return;
    if (type == 'call.ended' && event['call_id'] == room!.id) {
      await clear();
      return;
    }
    if (type == 'call.state' && event['call']['id'] == room!.id) {
      room = CallRoom.fromJson(event['call']);
      final ids = room!.participants.map((p) => p.user.id).toSet();
      for (final id in peers.keys.toList()) {
        if (!ids.contains(id)) await _removePeer(id);
      }
      _notify();
      return;
    }
    if (type != 'signal' || event['call_id'] != room!.id) return;
    final id = event['from'] as String;
    final data = event['data'] as Json;
    final peer = await _peer(id);
    if (data['description'] != null) {
      final d = data['description'];
      if (!['offer', 'answer'].contains(d['type'])) return;
      await peer.connection.setRemoteDescription(
        RTCSessionDescription(d['sdp'], d['type']),
      );
      peer.hasRemoteDescription = true;
      for (final candidate in peer.candidates) {
        await peer.connection.addCandidate(candidate);
      }
      peer.candidates.clear();
      if (d['type'] == 'offer') {
        final answer = await peer.connection.createAnswer();
        final description = RTCSessionDescription(
          _voiceSDP(answer.sdp!),
          answer.type,
        );
        await peer.connection.setLocalDescription(description);
        final current = room;
        if (current != null) {
          send({
            'type': 'signal',
            'chat_id': current.chatId,
            'call_id': current.id,
            'to': id,
            'data': {'description': description.toMap()},
          });
        }
      }
    } else if (data['candidate'] != null) {
      final c = data['candidate'];
      final candidate = RTCIceCandidate(
        c['candidate'],
        c['sdpMid'],
        c['sdpMLineIndex'],
      );
      if (peer.hasRemoteDescription) {
        await peer.connection.addCandidate(candidate);
      } else if (peer.candidates.length < 128) {
        peer.candidates.add(candidate);
      }
    }
  }

  Future<void> _refreshStats() async {
    final epoch = _epoch;
    final values = <int>[];
    for (final peer in peers.values.toList()) {
      try {
        final stats = await peer.connection.getStats();
        for (final stat in stats) {
          final v = stat.values;
          if (stat.type == 'candidate-pair' &&
              v['state'] == 'succeeded' &&
              (v['nominated'] == true || v['selected'] == true) &&
              v['currentRoundTripTime'] is num) {
            values.add(((v['currentRoundTripTime'] as num) * 1000).round());
          }
        }
      } catch (_) {
        /* The peer may have left while stats were in flight. */
      }
    }
    if (epoch != _epoch) return;
    roundTripMs = values.isEmpty
        ? null
        : values.reduce((a, b) => a > b ? a : b);
    _notify();
  }

  void toggleMute() {
    if (room == null) return;
    muted = !muted;
    for (final track in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    send({
      'type': 'call.mute',
      'chat_id': room!.chatId,
      'call_id': room!.id,
      'muted': muted,
    });
    _notify();
  }

  Future<void> toggleSpeaker() async {
    try {
      await Helper.setSpeakerphoneOn(!speaker);
      speaker = !speaker;
      _notify();
    } catch (_) {
      onError('Не вдалося перемкнути аудіовихід');
    }
  }

  Future<void> _removePeer(String id) async {
    final peer = peers.remove(id);
    if (peer == null) return;
    peer.renderer.srcObject = null;
    await peer.connection.close();
    await peer.connection.dispose();
    await peer.renderer.dispose();
  }

  Future<void> hangUp() async {
    final current = room;
    if (current != null) {
      send({
        'type': 'call.leave',
        'chat_id': current.chatId,
        'call_id': current.id,
      });
    }
    await clear();
  }

  Future<void> clear() async {
    ++_epoch;
    _stats?.cancel();
    _stats = null;
    room = null;
    joiningChat = null;
    roundTripMs = null;
    if (_joined?.isCompleted == false) _joined!.complete();
    _joined = null;
    final local = _local;
    _local = null;
    for (final id in peers.keys.toList()) {
      await _removePeer(id);
    }
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await local?.dispose();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(clear());
    super.dispose();
  }
}
