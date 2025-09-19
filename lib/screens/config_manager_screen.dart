import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/config_file_service.dart';
import 'config_editor_screen.dart';
import 'package:flutter/services.dart';
import '../services/tunnel_service.dart';
import '../services/frp_config_service.dart';

class ConfigManagerScreen extends StatefulWidget {
  const ConfigManagerScreen({super.key});

  @override
  State<ConfigManagerScreen> createState() => _ConfigManagerScreenState();
}

class _ConfigManagerScreenState extends State<ConfigManagerScreen> {
  List<File> _configs = [];
  String? _activePath;
  bool _loading = true;
  bool _initial = true;
  static bool _didInitialStop = false;

  @override
  void initState() {
    super.initState();
    if (!_didInitialStop) {
      _ensureStoppedThenRefresh();
      _didInitialStop = true;
    } else {
      _refresh();
    }
  }

  Future<void> _ensureStoppedThenRefresh() async {
    // Stop any residual frpc process and clear active flag.
    await TunnelService.instance.stop();
    await ConfigFileService.instance.setActivePath(null);
    _refresh();
  }

  Future<void> _refresh() async {
    if (_initial) setState(() => _loading = true);
    final list = await ConfigFileService.instance.listConfigs();
    final active = await ConfigFileService.instance.getActivePath();
    setState(() {
      _configs = list.map((e) => File(e.path)).toList();
      _activePath = active;
      _loading = false;
      _initial = false;
    });
  }

  Future<void> _delete(File file) async {
    await ConfigFileService.instance.delete(file);
    if (_activePath == file.path) {
      await ConfigFileService.instance.setActivePath(null);
    }
    await _refresh();
  }

  Future<void> _toggleEnable(File file, bool enable) async {
    if (enable) {
      if (_activePath != null && _activePath != file.path) {
        await TunnelService.instance.stop();
      }
      final content = await file.readAsString();
      await ConfigFileService.instance.setActivePath(file.path);
      await FrpConfigService.instance.saveRawToml(content);
      try {
        await TunnelService.instance.startFrp();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('启动失败: $e')),
          );
        }
        await ConfigFileService.instance.setActivePath(null);
        setState(() => _activePath = null);
        return;
      }
    } else {
      await ConfigFileService.instance.setActivePath(null);
      await TunnelService.instance.stop();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('frp0.63.0'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final file = await ConfigFileService.instance.createNew();
          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ConfigEditorScreen(file: file)),
            );
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _configs.isEmpty
                      ? Center(
                          child: Text('暂无配置，点击右下角按钮添加配置',
                              style: TextStyle(color: Colors.grey[600])),
                        )
                      : Column(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: (_configs.length.clamp(0,4))*72.0),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: _configs.length,
                                itemBuilder: (context, index) {
                                  final file = _configs[index];
                                  final name = file.uri.pathSegments.last;
                                  final enabled = _activePath == file.path;
                                  return ListTile(
                                    title: Text(name),
                                    leading: Switch(
                                      value: enabled,
                                      onChanged: (v) => _toggleEnable(file, v),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => ConfigEditorScreen(file: file)),
                                            );
                                            _refresh();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _delete(file),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Expanded(child: _LogPanel()),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _LogPanel extends StatefulWidget {
  const _LogPanel({super.key});
  @override
  State<_LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<_LogPanel> {
  final List<String> _logs = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _logs.addAll(TunnelService.instance.logHistory);
    _sub = TunnelService.instance.logStream.listen((line) {
      setState(() {
        _logs.add(line);
        if (_logs.length > 500) _logs.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('frp 日志', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _logs.clear()),
                child: const Text('清除'),
              ),
              TextButton(
                onPressed: () {
                  final all = _logs.join('\n');
                  Clipboard.setData(ClipboardData(text: all));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制日志')));
                },
                child: const Text('复制'),
              ),
            ],
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final line = _logs[index];
                  return GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: line));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
                    },
                    child: SelectableText(line, style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
} 