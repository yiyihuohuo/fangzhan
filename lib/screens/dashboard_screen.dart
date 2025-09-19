import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isRunning = context.watch<AppProvider>().serverRunning;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(isRunning: isRunning),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: const [
                  _FeatureCard(
                    icon: Icons.web,
                    label: '仿站管理',
                    routeName: '/sites',
                  ),
                  _FeatureCard(
                    icon: Icons.data_exploration,
                    label: '数据捕获',
                    routeName: '/capture',
                  ),
                  _FeatureCard(
                    icon: Icons.cloud,
                    label: '穿透配置',
                    routeName: '/tunnel',
                  ),
                  _FeatureCard(
                    icon: Icons.language,
                    label: '网页测试',
                    routeName: '/webtest',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isRunning});
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(isRunning ? Icons.check_circle : Icons.stop_circle, color: isRunning ? Colors.green : Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRunning ? '服务运行中' : '服务已停止',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton(
              onPressed: () => context.read<AppProvider>().toggleServer(),
              style: FilledButton.styleFrom(
                backgroundColor: isRunning ? Colors.red[400] : Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isRunning ? '停止' : '启动',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.routeName,
  });

  final IconData icon;
  final String label;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed(routeName);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
} 