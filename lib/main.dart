import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/history_provider.dart';
import 'providers/ip_provider.dart';
import 'screens/home_shell.dart';
import 'theme/pikayun_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authProvider});

  final AuthProvider? authProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider ?? AuthProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProxyProvider<HistoryProvider, IpProvider>(
          create: (context) => IpProvider(
            history: context.read<HistoryProvider>(),
          ),
          update: (_, history, previous) =>
              previous ?? IpProvider(history: history),
        ),
      ],
      child: MaterialApp(
        title: 'IP 位置查询',
        debugShowCheckedModeBanner: false,
        theme: PikayunTheme.light(),
        darkTheme: PikayunTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
