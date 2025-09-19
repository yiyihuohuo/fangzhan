import 'package:flutter/material.dart';
import '../services/capture_service.dart';
import 'data_detail_screen.dart';
import 'package:flutter/services.dart';
import 'dart:async';

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

  List<Map<String,dynamic>> _displayed=[];

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
          _recalcDisplay();
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
        _recalcDisplay();
      });
    }
  }

  void _recalcDisplay(){
    Iterable<Map<String,dynamic>> filtered=_captures;
    final tab=_tabs[_tabController.index];
    if(tab!='全部'){
       if(tab=='PROBE') filtered=filtered.where((e)=>e['type']=='PROBE');
       else filtered=filtered.where((e)=>e['type']==tab);
    }
    if(_siteFilter!='全部站点') filtered=filtered.where((e)=>(e['site']??'')==_siteFilter);
    if(_keyword.isNotEmpty) filtered=filtered.where((e)=>(e['body']??'').toString().contains(_keyword) || (e['headers']??'').toString().contains(_keyword));
    _displayed=filtered.toList();
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
                      _recalcDisplay();
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
                      _debounce=Timer(const Duration(milliseconds:300),(){if(mounted){setState(_recalcDisplay);} });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((e) {
                final listFiltered=_displayed;
                if (listFiltered.isEmpty) {
                  return const Center(child: Text('暂无数据'));
                }
                return ListView.builder(
                  itemCount: listFiltered.length,
                  itemBuilder: (context, index) {
                    final item = listFiltered[index];
                    return ListTile(
                      title: Text('${item['type']}  ${DateTime.fromMillisecondsSinceEpoch(item['time']).toLocal()}'),
                      subtitle: Text('${item['site'] ?? ''} | ' + ((item['body'] as String).startsWith('FILE:') ? '图片/大文件' : ((item['body'] as String).isEmpty ? '无正文' : item['body']))),
                      onTap: () async {
                        final full=await CaptureService.instance.getCapture(item['id']);
                        if(full!=null && mounted){
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
                                leading: const Icon(Icons.delete),
                                title: const Text('删除'),
                                onTap: () => Navigator.pop(context, 'delete'),
                              ),
                            ],
                          ),
                        );
                        if (res == 'delete') {
                          await CaptureService.instance.deleteCapture(item['id']);
                        }
                      },
                    );
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

  @override bool get wantKeepAlive => true;
} 