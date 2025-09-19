import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/capture_service.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class DataDetailScreen extends StatelessWidget {
  const DataDetailScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  Map<String, dynamic> get _parsed {
    final parsed = <String, dynamic>{};
    // 解析请求头
    try {
      parsed['headers'] = jsonDecode(data['headers'] ?? '{}');
    } catch (_) {
      parsed['headers'] = data['headers'];
    }

    // 解析 body
    final bodyStr = data['body'] as String? ?? '';
    if (bodyStr.trim().isEmpty) {
      parsed['body'] = '<empty>';
    } else {
      // 尝试 JSON
      try {
        parsed['body'] = jsonDecode(bodyStr);
      } catch (_) {
        // 尝试表单 urlencoded
        if (bodyStr.contains('=')) {
          parsed['body'] = Uri.splitQueryString(bodyStr);
        } else {
          parsed['body'] = bodyStr;
        }
      }
    }

    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final bodyStr = data['body'] as String? ?? '';
    Widget rawWidget;
    if (bodyStr.startsWith('FILE:')) {
      final path = bodyStr.substring(5);
      rawWidget = Center(child: Image.file(File(path)));
    } else {
      rawWidget = _buildJsonView(data);
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('数据详情'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '原始数据'),
              Tab(text: '解析数据'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            rawWidget,
            _buildJsonView(_parsed),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  final encoder = const JsonEncoder.withIndent('  ');
                  final str = encoder.convert(data);
                  Clipboard.setData(ClipboardData(text: str));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  // TODO: export data
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await CaptureService.instance.deleteCapture(data['id']);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJsonView(Map<String, dynamic> json) {
    final encoder = const JsonEncoder.withIndent('  ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: SelectableText(encoder.convert(json)),
    );
  }
} 