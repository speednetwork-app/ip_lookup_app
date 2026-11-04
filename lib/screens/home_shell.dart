import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import 'account_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'nodes_screen.dart';
import 'store_screen.dart';

/// 底部导航外壳。用 IndexedStack 而不是每次重建页面，
/// 这样切走再切回来时输入框内容和滚动位置都还在。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final AuthProvider _auth;

  Future<bool> _confirmInsecureHy2(String nodeName) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog.adaptive(
            title: const Text('HY2 证书兼容连接'),
            content: SingleChildScrollView(
              child: Text('线路：$nodeName\n\n'
                  '此线路要求跳过服务器证书校验。流量仍会加密，但无法验证服务器身份，存在服务器被冒充或中间人攻击的风险。\n\n'
                  '仅在你信任该线路并了解上述风险时继续。VLESS 和其他已验证线路不受影响。'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('了解风险，继续')),
            ],
          ),
        ) ==
        true;
  }

  void _selectTab(int index) {
    setState(() => _index = index);
    if (index == 1) {
      final auth = context.read<AuthProvider>();
      if (auth.isSignedIn && auth.networkNodes.isEmpty) {
        Future.microtask(auth.refreshNetworkNodes);
      }
    }
    if (index == 3) {
      Future.microtask(context.read<AuthProvider>().refreshStorePlans);
    }
  }

  @override
  void initState() {
    super.initState();
    final history = context.read<HistoryProvider>();
    Future.microtask(history.load);
    final auth = context.read<AuthProvider>();
    _auth = auth;
    auth.confirmInsecureHy2 = _confirmInsecureHy2;
    Future.microtask(auth.initialize);
    Future.microtask(auth.initializeVpn);
  }

  @override
  void dispose() {
    _auth.confirmInsecureHy2 = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onOpenNodes: () => _selectTab(1),
            onOpenAccount: () => _selectTab(4),
            onOpenIp: () => _selectTab(2),
          ),
          NodesScreen(onOpenAccount: () => _selectTab(4)),
          const HomeScreen(),
          StoreScreen(onOpenAccount: () => _selectTab(4)),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: '线路',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'IP 检测',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '商城',
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
