import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/history_provider.dart';
import 'providers/ip_provider.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        // IpProvider 依赖 HistoryProvider 来记录查询——用 Proxy 注入，
        // 这样"查询成功就写历史"只写在一个地方。
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
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
