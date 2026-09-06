import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chat_controller.dart';
import 'theme.dart';

class AuthScreen extends StatefulWidget {
  final ChatController controller;
  const AuthScreen({super.key, required this.controller});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _server;
  final _username = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController();
  bool _register = false, _visible = false;
  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.controller.api.server);
  }

  @override
  void dispose() {
    for (final c in [_server, _username, _password, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (widget.controller.busy || !_form.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    widget.controller.authenticate(
      server: _server.text,
      username: _username.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
      register: _register,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 940;
            return Row(
              children: [
                if (wide)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: night,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              BrandMark(),
                              SizedBox(width: 13),
                              Text(
                                'spayr',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'Менше відстані.\nБільше розмов.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              height: 1.13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.7,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Ваші люди — за одне повідомлення.\nАбо за один дзвінок.',
                            style: TextStyle(
                              color: Color(0xFFADAFC4),
                              fontSize: 17,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 44),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF292D46),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Row(
                              children: [
                                BrandMark(size: 50),
                                SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Голос, що зближує',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Особисті та групові аудіодзвінки',
                                        style: TextStyle(
                                          color: Color(0xFFB7B8CD),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'iOS  ·  Android  ·  Windows  ·  macOS',
                            style: TextStyle(
                              color: Color(0xFF898DA7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 48 : 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: AutofillGroup(
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!wide) ...[
                                  const BrandMark(size: 54),
                                  const SizedBox(height: 32),
                                ],
                                Text(
                                  _register
                                      ? 'Раді знайомству'
                                      : 'З поверненням',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _register
                                      ? 'Створіть акаунт і почніть свою першу розмову.'
                                      : 'Увійдіть, щоб бути ближче до своїх.',
                                  style: const TextStyle(
                                    color: mutedInk,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                if (controller.error != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ErrorStrip(
                                      message: controller.error!,
                                      onDismiss: controller.dismissError,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                if (_register) ...[
                                  _label('Ваше ім’я'),
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    maxLength: 48,
                                    decoration: const InputDecoration(
                                      hintText: 'Як до вас звертатися?',
                                      counterText: '',
                                    ),
                                    validator: (v) =>
                                        (v?.trim().isEmpty ?? true)
                                        ? 'Вкажіть ім’я'
                                        : null,
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                _label('Логін'),
                                TextFormField(
                                  controller: _username,
                                  autofillHints: const [AutofillHints.username],
                                  autocorrect: false,
                                  decoration: const InputDecoration(
                                    hintText: 'your_name',
                                    prefixIcon: Icon(
                                      Icons.alternate_email_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (v) =>
                                      RegExp(
                                        r'^[a-zA-Z0-9_]{3,24}$',
                                      ).hasMatch(v?.trim() ?? '')
                                      ? null
                                      : '3–24 латинські літери, цифри або _',
                                ),
                                const SizedBox(height: 18),
                                _label('Пароль'),
                                TextFormField(
                                  controller: _password,
                                  obscureText: !_visible,
                                  autofillHints: [
                                    _register
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    hintText: 'Щонайменше 8 символів',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _visible = !_visible),
                                      tooltip: _visible
                                          ? 'Приховати пароль'
                                          : 'Показати пароль',
                                      icon: Icon(
                                        _visible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => (v?.length ?? 0) < 8
                                      ? 'Щонайменше 8 символів'
                                      : null,
                                ),
                                const SizedBox(height: 22),
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: const EdgeInsets.only(
                                    bottom: 18,
                                  ),
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  leading: const Icon(
                                    Icons.dns_outlined,
                                    size: 20,
                                    color: mutedInk,
                                  ),
                                  title: const Text(
                                    'Ваш сервер',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    controller.api.server,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: mutedInk,
                                    ),
                                  ),
                                  children: [
                                    TextFormField(
                                      controller: _server,
                                      keyboardType: TextInputType.url,
                                      autocorrect: false,
                                      decoration: const InputDecoration(
                                        hintText: 'https://chat.example.com',
                                        labelText: 'Адреса сервера',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Для тесту на цьому ПК: http://localhost:8080.\nНа телефоні вкажіть локальну IP-адресу ПК. Для інтернету використовуйте HTTPS.',
                                      style: TextStyle(
                                        color: mutedInk,
                                        fontSize: 11,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: controller.busy ? null : _submit,
                                    child: controller.busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _register
                                                    ? 'Створити акаунт'
                                                    : 'Увійти',
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _register
                                            ? 'Уже з нами?'
                                            : 'Ще немає акаунта?',
                                        style: const TextStyle(
                                          color: mutedInk,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: controller.busy
                                            ? null
                                            : () {
                                                setState(
                                                  () => _register = !_register,
                                                );
                                                controller.dismissError();
                                              },
                                        child: Text(
                                          _register
                                              ? 'Увійти'
                                              : 'Зареєструватися',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Center(
                                  child: Text(
                                    'Свій сервер. Свій простір для спілкування.',
                                    style: TextStyle(
                                      color: mutedInk,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
