import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../providers/ip_provider.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'lookup_screen.dart';

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
    final ip = context.read<IpProvider>();
    final history = context.read<HistoryProvider>();
    Future.microtask(() async {
      // 先读历史再查 IP——查询成功会写历史，顺序反了会把刚存的覆盖掉。
      await history.load();
      await ip.loadMyIp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          LookupScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.my_location_outlined),
            selectedIcon: Icon(Icons.my_location),
            label: '我的 IP',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '查询',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
        ],
      ),
    );
  }
}
