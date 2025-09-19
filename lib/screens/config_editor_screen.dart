import 'dart:io';
import '../services/config_file_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConfigEditorScreen extends StatefulWidget {
  final File file;
  const ConfigEditorScreen({super.key, required this.file});

  @override
  State<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends State<ConfigEditorScreen> {
  late TextEditingController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txt = await widget.file.readAsString();
    setState(() {
      _ctrl = TextEditingController(text: txt);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await widget.file.writeAsString(_ctrl.text);
  }

  Future<void> _rename() async {
    final nameCtrl = TextEditingController(text: widget.file.uri.pathSegments.last);
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: nameCtrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (ok != null && ok.isNotEmpty) {
      await ConfigFileService.instance.rename(widget.file, ok);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('frp0.63.0'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: () async { await _save(); Navigator.pop(context, true);} ),
          IconButton(icon: const Icon(Icons.close), onPressed: () { Navigator.pop(context, false);} ),
          IconButton(icon: const Icon(Icons.drive_file_rename_outline), onPressed: _rename),
        ],
      ),
      body: Column(
        children: [
          const SizedBox.shrink(),
          const Divider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 