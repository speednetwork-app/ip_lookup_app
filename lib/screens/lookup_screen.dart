import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ip_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/ip_card.dart';

class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key});

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<IpProvider>().lookup(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('查询 IP')),
      body: Consumer<IpProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '输入 IPv4 或 IPv6 地址，如 8.8.8.8',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.language),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清空输入',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  provider.clearResults();
                                  setState(() {});
                                },
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: provider.isLoading ? null : _submit,
                      icon: const Icon(Icons.search),
                      label: const Text('开始查询'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '输入的 IP 地址会发送至 ipwho.is；服务不可用时会改用 '
                      'ipapi.co。本 App 不访问设备 GPS 定位。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(IpProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error.isNotEmpty) {
      return ErrorView(message: provider.error, onRetry: _submit);
    }

    if (provider.result != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [IpCard(ipInfo: provider.result!)],
      );
    }

    return const SingleChildScrollView(
      child: EmptyState(
        icon: Icons.travel_explore,
        title: '查询 IP 的大致归属地',
        message: '输入一个 IPv4 或 IPv6 地址，查看国家、城市、时区和运营商',
      ),
    );
  }
}
