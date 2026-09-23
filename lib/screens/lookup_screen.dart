import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ip_provider.dart';
import '../services/ip_api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/ip_card.dart';

class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key});

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final _controller = TextEditingController();
  bool _batchMode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final provider = context.read<IpProvider>();
    if (_batchMode) {
      provider.lookupBatch(_controller.text);
    } else {
      provider.lookup(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('查询 IP'),
        actions: [
          IconButton(
            tooltip: _batchMode ? '切换到单个查询' : '切换到批量查询',
            icon: Icon(_batchMode ? Icons.looks_one_outlined : Icons.list_alt),
            onPressed: () {
              setState(() => _batchMode = !_batchMode);
              context.read<IpProvider>().clearResults();
            },
          ),
        ],
      ),
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
                      maxLines: _batchMode ? 5 : 1,
                      minLines: _batchMode ? 3 : 1,
                      textInputAction: _batchMode
                          ? TextInputAction.newline
                          : TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: _batchMode
                            ? '每行一个 IP，或用逗号/空格分隔\n最多 ${IpApiService.maxBatchSize} 个'
                            : '输入 IP 地址，如 8.8.8.8',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.language),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  provider.clearResults();
                                  setState(() {});
                                },
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _batchMode ? null : (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: provider.isLoading ? null : _submit,
                      icon: const Icon(Icons.search),
                      label: Text(_batchMode ? '批量查询' : '查询'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
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
    final progress = provider.batchProgress;
    if (progress != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress.fraction),
            const SizedBox(height: 16),
            Text('已查询 ${progress.done} / ${progress.total}'),
          ],
        ),
      );
    }

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error.isNotEmpty) {
      return ErrorView(message: provider.error, onRetry: _submit);
    }

    if (provider.batchResults.isNotEmpty) {
      return _BatchResultList(results: provider.batchResults);
    }

    if (provider.result != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [IpCard(ipInfo: provider.result!)],
      );
    }

    return EmptyState(
      icon: _batchMode ? Icons.list_alt : Icons.travel_explore,
      title: _batchMode ? '批量查询多个 IP' : '查询任意 IP 的归属地',
      message: _batchMode
          ? '粘贴一组 IP 地址，一次查完它们的国家、城市和运营商'
          : '输入一个 IPv4 或 IPv6 地址，查看它的国家、城市、时区和运营商',
    );
  }
}

class _BatchResultList extends StatelessWidget {
  const _BatchResultList({required this.results});

  final List<BatchResult> results;

  @override
  Widget build(BuildContext context) {
    final ok = results.where((r) => r.isSuccess).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '成功 $ok / ${results.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = results[i];
              final scheme = Theme.of(context).colorScheme;

              if (!r.isSuccess) {
                return ListTile(
                  tileColor: scheme.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(Icons.error_outline, color: scheme.error),
                  title: Text(r.query),
                  subtitle: Text(
                    r.error!,
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                );
              }

              final info = r.info!;
              return ListTile(
                tileColor: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.place_outlined),
                title: Text(info.ip),
                subtitle: Text('${info.location} · ${info.isp}'),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.8,
                    builder: (_, controller) => ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [IpCard(ipInfo: info)],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
