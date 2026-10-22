import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import 'account_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// 底部导航外壳。用 IndexedStack 而不是每次重建页面，
/// 这样切走再切回来时输入框内容和滚动位置都还在。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final history = context.read<HistoryProvider>();
    Future.microtask(history.load);
    final auth = context.read<AuthProvider>();
    Future.microtask(auth.initialize);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onOpenIpTools: () => setState(() => _index = 1),
            onOpenHistory: () => setState(() => _index = 2),
            onOpenAccount: () => setState(() => _index = 3),
          ),
          const HomeScreen(),
          const HistoryScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'IP 检测',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
