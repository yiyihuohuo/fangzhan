import 'package:flutter/material.dart';
import '../services/capture_service.dart';
import 'data_detail_screen.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

class DataCaptureScreen extends StatefulWidget {
  const DataCaptureScreen({super.key});

  @override
  State<DataCaptureScreen> createState() => _DataCaptureScreenState();
}

class _DataCaptureScreenState extends State<DataCaptureScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    '全部',
    'POST',
    'GET',
    'PROBE',
  ];

  List<Map<String, dynamic>> _captures = [];
  StreamSubscription? _sub;
  String _siteFilter = '全部站点';
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // 初次加载
    _load();

    // 监听后续变化
    _sub = CaptureService.instance.capturesStream.listen((data) {
      if(mounted){
        setState(() {
          _captures = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await CaptureService.instance.fetchCaptures(preview:true);
    if(mounted){
      setState(() {
        _captures = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          TabBar(controller:_tabController,tabs:_tabs.map((e)=>Tab(text:e)).toList()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _siteFilter,
                  items: [
                    '全部站点',
                    ...{..._captures.map((e) => e['site'] ?? '')}.where((e) => e.toString().isNotEmpty)
                  ].cast<String>()
                   .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                  onChanged: (v){
                    setState((){
                      _siteFilter=v!;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: '搜索关键字',
                      isDense: true,
                    ),
                    onChanged: (v){
                      _keyword=v;
                      _debounce?.cancel();
                      _debounce=Timer(const Duration(milliseconds:300),(){if(mounted){setState(() {});} });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tabName) {
                // 为每个标签动态计算对应的数据
                Iterable<Map<String,dynamic>> tabFiltered = _captures;
                
                // 按标签类型筛选
                if(tabName != '全部'){
                  switch(tabName) {
                    case 'POST':
                      tabFiltered = tabFiltered.where((e) => e['type'] == 'POST' || ['FORM', 'FORM_SNAPSHOT', 'FORM_SUBMIT', 'FORM_INITIAL', 'FORM_FINAL', 'FORM_PERIODIC', 'CLICK', 'INPUT'].contains(e['type']));
                      break;
                    case 'GET':
                      tabFiltered = tabFiltered.where((e) => e['type'] == 'GET' || ['XHR', 'FETCH', 'REQUEST'].contains(e['type']));
                      break;
                    case 'PROBE':
                      tabFiltered = tabFiltered.where((e) => e['type'] == 'PROBE' || ['GPS', 'CAMERA', 'CLIPBOARD', 'DEVICE_INFO', 'PAGE_READY'].contains(e['type']));
                      break;
                  }
                }
                
                // 按站点筛选
                if(_siteFilter != '全部站点') {
                  tabFiltered = tabFiltered.where((e) => (e['site'] ?? '') == _siteFilter);
                }
                
                // 按关键字筛选
                if(_keyword.isNotEmpty) {
                  tabFiltered = tabFiltered.where((e) => (e['body'] ?? '').toString().contains(_keyword) || (e['headers'] ?? '').toString().contains(_keyword));
                }
                
                final listFiltered = tabFiltered.toList();
                
                if (listFiltered.isEmpty) {
                  return const Center(child: Text('暂无数据'));
                }
                return ListView.builder(
                  itemCount: listFiltered.length,
                  itemBuilder: (context, index) {
                    final item = listFiltered[index];
                    return _buildCaptureItem(item);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final jsonStr = await CaptureService.instance.exportCapturesPretty();
                  await Clipboard.setData(ClipboardData(text: jsonStr));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('导出数据'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认清空?'),
                      content: const Text('此操作将删除所有捕获记录，无法恢复。'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await CaptureService.instance.clearAll();
                  }
                },
                icon: const Icon(Icons.delete),
                label: const Text('清空记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建捕获项目的 Widget
  Widget _buildCaptureItem(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final time = DateTime.fromMillisecondsSinceEpoch(item['time']).toLocal();
    final site = item['site'] ?? '';
    final body = item['body'] as String;
    
    // 根据类型设置不同的颜色
    Color color;
    String subtitle;
    
    switch (type) {
      case 'FORM_SNAPSHOT':
        color = Colors.green;
        subtitle = _extractFormSnapshotData(body);
        break;
      case 'FORM_SUBMIT':
      case 'FORM_INITIAL':
      case 'FORM_FINAL':
      case 'FORM_PERIODIC':
        color = Colors.blue;
        subtitle = _extractFormData(body);
        break;
      case 'CLICK':
        color = Colors.purple;
        subtitle = _extractClickData(body);
        break;
      case 'GPS':
        color = Colors.red;
        subtitle = '位置信息';
        break;
      case 'CAMERA':
        color = Colors.pink;
        subtitle = '摄像头数据';
        break;
      case 'CLIPBOARD':
        color = Colors.teal;
        subtitle = '剪贴板内容';
        break;
      case 'DEVICE_INFO':
        color = Colors.indigo;
        subtitle = '设备信息';
        break;
      case 'PAGE_READY':
        color = Colors.cyan;
        subtitle = '页面加载完成';
        break;
      default:
        color = Colors.grey;
        subtitle = body.isEmpty ? '无数据' : (body.length > 50 ? '${body.substring(0, 50)}...' : body);
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (site.isNotEmpty) 
              Text(
                site,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        onTap: () async {
          final full = await CaptureService.instance.getCapture(item['id']);
          if (full != null && mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DataDetailScreen(data: full),
            ));
          }
        },
        onLongPress: () async {
          final res = await showModalBottomSheet<String>(
            context: context,
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('删除此记录'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('复制数据'),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
              ],
            ),
          );
          
          if (res == 'delete') {
            await CaptureService.instance.deleteCapture(item['id']);
          } else if (res == 'copy') {
            await Clipboard.setData(ClipboardData(text: body));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据已复制到剪贴板')),
              );
            }
          }
        },
      ),
    );
  }
  
  /// 提取表单快照数据摘要
  String _extractFormSnapshotData(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('payload')) {
        final payload = data['payload'];
        if (payload is Map && payload.containsKey('forms')) {
          final forms = payload['forms'] as Map;
          final formCount = forms.length;
          final trigger = payload['trigger'] as Map?;
          final triggerText = trigger?['text']?.toString() ?? trigger?['tagName']?.toString() ?? '未知';
          
          // 统计总字段数
          int totalFields = 0;
          forms.values.forEach((form) {
            if (form is Map && form.containsKey('data')) {
              totalFields += (form['data'] as Map).length;
            }
          });
          
          return '点击"$triggerText"时捕获: $formCount个表单, $totalFields个字段';
        }
      }
    } catch (_) {}
    return '表单快照数据';
  }

  /// 提取表单数据摘要
  String _extractFormData(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('payload')) {
        final payload = data['payload'];
        if (payload is Map) {
          // 新格式：包含 forms
          if (payload.containsKey('forms')) {
            final forms = payload['forms'] as Map;
            int totalFields = 0;
            forms.values.forEach((form) {
              if (form is Map && form.containsKey('data')) {
                totalFields += (form['data'] as Map).length;
              }
            });
            return '${forms.length}个表单, $totalFields个字段';
          }
          // 旧格式：直接包含 data
          else if (payload.containsKey('data')) {
            final formData = payload['data'] as Map;
            final fields = formData.keys.take(3).join(', ');
            return '表单字段: $fields';
          }
        }
      }
    } catch (_) {}
    return '表单提交数据';
  }
  
  /// 提取请求数据摘要
  String _extractRequestData(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('payload')) {
        final payload = data['payload'];
        if (payload is Map) {
          final url = payload['url']?.toString() ?? '';
          final method = payload['method']?.toString() ?? '';
          return '$method ${url.length > 30 ? url.substring(0, 30) + '...' : url}';
        }
      }
    } catch (_) {}
    return '网络请求';
  }
  
  /// 提取输入数据摘要
  String _extractInputData(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('payload')) {
        final payload = data['payload'];
        if (payload is Map) {
          final name = payload['name']?.toString() ?? '';
          final value = payload['value']?.toString() ?? '';
          final type = payload['type']?.toString() ?? '';
          
          if (type == 'password' || name.toLowerCase().contains('password')) {
            return '密码输入: ${name.isNotEmpty ? name : '未知字段'}';
          }
          
          return '输入: ${name.isNotEmpty ? name : type} = ${value.length > 20 ? value.substring(0, 20) + '...' : value}';
        }
      }
    } catch (_) {}
    return '用户输入';
  }
  
  /// 提取点击数据摘要
  String _extractClickData(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('payload')) {
        final payload = data['payload'];
        if (payload is Map) {
          final tagName = payload['tagName']?.toString() ?? '';
          final text = payload['text']?.toString() ?? '';
          final id = payload['id']?.toString() ?? '';
          
          String target = tagName.toUpperCase();
          if (id.isNotEmpty) target += '#$id';
          if (text.isNotEmpty) target += ': ${text.length > 20 ? text.substring(0, 20) + '...' : text}';
          
          return '点击 $target';
        }
      }
    } catch (_) {}
    return '页面点击';
  }

  @override bool get wantKeepAlive => true;
} 