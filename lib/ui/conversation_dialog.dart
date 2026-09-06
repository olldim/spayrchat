import 'dart:async';
import 'package:flutter/material.dart';
import '../chat_controller.dart';
import '../models.dart';
import 'theme.dart';

class ConversationDialog extends StatefulWidget {
  final ChatController controller;
  const ConversationDialog({super.key, required this.controller});
  @override
  State<ConversationDialog> createState() => _ConversationDialogState();
}

class _ConversationDialogState extends State<ConversationDialog> {
  final _search = TextEditingController(), _name = TextEditingController();
  final Map<String, ChatUser> _chosen = {};
  List<ChatUser> _results = [];
  bool _group = false, _loading = false, _saving = false;
  String? _error;
  Timer? _debounce;
  int _version = 0;
  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _query(String q) {
    _debounce?.cancel();
    final version = ++_version;
    setState(() {
      _error = null;
      _loading = q.trim().length >= 2;
      _results = [];
    });
    if (q.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final users = await widget.controller.searchUsers(q.trim());
        if (mounted && version == _version) setState(() => _results = users);
      } catch (e) {
        if (mounted && version == _version) {
          setState(() => _error = e.toString());
        }
      } finally {
        if (mounted && version == _version) setState(() => _loading = false);
      }
    });
  }

  Future<void> _create() async {
    if (_chosen.isEmpty || (_group && _name.text.trim().isEmpty)) {
      setState(
        () => _error =
            'Оберіть учасників${_group ? ' і введіть назву групи' : ''}',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.createChat(
        _chosen.keys.toList(),
        _name.text.trim(),
        _group,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 650),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Нова розмова',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Закрити',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Особиста'),
                  icon: Icon(Icons.person_outline_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Група'),
                  icon: Icon(Icons.group_outlined),
                ),
              ],
              selected: {_group},
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() {
                      _group = s.first;
                      if (!_group && _chosen.length > 1) _chosen.clear();
                    }),
            ),
            const SizedBox(height: 20),
            if (_group) ...[
              TextField(
                controller: _name,
                maxLength: 64,
                decoration: const InputDecoration(
                  hintText: 'Назва вашої групи',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: _query,
              decoration: const InputDecoration(
                hintText: 'Знайти за логіном або ім’ям',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            if (_chosen.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _chosen.values
                      .map(
                        (u) => InputChip(
                          label: Text(u.name),
                          onDeleted: _saving
                              ? null
                              : () => setState(() => _chosen.remove(u.id)),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            Flexible(
              child: _loading
                  ? const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _results.isEmpty
                  ? SizedBox(
                      height: 150,
                      child: Center(
                        child: Text(
                          _search.text.trim().length < 2
                              ? 'Введіть щонайменше 2 символи.\nДрузі мають зареєструватися на вашому сервері.'
                              : 'Нікого не знайдено',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: mutedInk,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final user = _results[i];
                        final selected = _chosen.containsKey(user.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                          leading: Avatar(
                            name: user.name,
                            size: 40,
                            online: user.online,
                          ),
                          title: Text(user.name),
                          subtitle: Text(
                            '@${user.username}',
                            style: const TextStyle(
                              color: mutedInk,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected ? violet : line,
                          ),
                          onTap: _saving
                              ? null
                              : () => setState(() {
                                  if (selected) {
                                    _chosen.remove(user.id);
                                  } else {
                                    if (!_group) _chosen.clear();
                                    _chosen[user.id] = user;
                                  }
                                }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _create,
                child: Text(
                  _saving
                      ? 'Створюємо…'
                      : _group
                      ? 'Створити групу'
                      : 'Почати розмову',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
