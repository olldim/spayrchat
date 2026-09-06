import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'chat_controller.dart';
import 'ui/auth_screen.dart';
import 'ui/chat_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpayrApp());
}

class SpayrApp extends StatefulWidget {
  const SpayrApp({super.key, this.controller});
  final ChatController? controller;
  @override
  State<SpayrApp> createState() => _SpayrAppState();
}

class _SpayrAppState extends State<SpayrApp> with WidgetsBindingObserver {
  late final ChatController controller;
  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? ChatController();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller == null) controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.resume();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      controller.foreground = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Spayr',
    debugShowCheckedModeBanner: false,
    theme: spayrTheme,
    locale: const Locale('uk'),
    supportedLocales: const [Locale('uk'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.booting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return controller.me == null
            ? AuthScreen(controller: controller)
            : ChatScreen(controller: controller);
      },
    ),
  );
}
