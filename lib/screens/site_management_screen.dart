import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/site_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/server_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class SiteManagementScreen extends StatefulWidget {
  const SiteManagementScreen({super.key});

  @override
  State<SiteManagementScreen> createState() => _SiteManagementScreenState();
}

class _SiteManagementScreenState extends State<SiteManagementScreen> with AutomaticKeepAliveClientMixin {
  List<Site> _sites = [];
  bool _loading = true;
  String _search = '';
  Timer? _debounce;

  List<Site> _filteredSites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _sites = await context.read<AppProvider>().fetchSites();
    _updateFiltered();
    setState(() => _loading = false);
  }

  void _updateFiltered() {
    _filteredSites = _sites.where((s) => s.name.contains(_search)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜索站点',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) {
                      _search = v;
                      // debounce to avoid rebuild on every keystroke
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds:300),(){
                        if(mounted){
                          setState(_updateFiltered);
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _filteredSites.length,
                      itemBuilder: (context, index) {
                        final site = _filteredSites[index];
                        return Card(
                          child: ListTile(
                            title: Text(site.name),
                            subtitle: Text('${site.path}\n端口:${site.port??'-'} / 🔒${site.securePort??'-'} | 探针:${_probeString(site)}'),
                            trailing: Switch(
                              value: site.enabled,
                              onChanged: (val) async {
                                site.enabled = val;
                                await SiteService.instance.updateSite(site);
                                if (val) {
                                  await ServerService.instance.startSite(site);
                                } else {
                                  await ServerService.instance.stopSite(site);
                                }
                                setState(() {});
                              },
                            ),
                            onTap: () async {
                              if (!site.enabled) {
                                await ServerService.instance.startSite(site);
                                setState(() {});
                              }
                              Navigator.push(context, MaterialPageRoute(builder: (_) => _SitePreview(site: site)));
                            },
                            onLongPress: () async {
                              final res = await showModalBottomSheet<String>(
                                context: context,
                                builder: (_) => _SiteActionSheet(site: site),
                              );
                              if (res == 'probes') {
                                _editProbes(site);
                              } else if (res == 'delete') {
                                await ServerService.instance.stopSite(site);
                                await SiteService.instance.deleteSite(site.id);
                                _load();
                              } else if (res == 'browser') {
                                final url='http://localhost:${site.port??ServerService.instance.getPort(site.id)}';
                                if(await canLaunchUrl(Uri.parse(url))){
                                  await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication);
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final urlController = TextEditingController();
          final nameController = TextEditingController();
          bool gps=false,camera=false,clip=false,ip=false,device=false;
          String ua='wechat';
          final res = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('添加站点'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: urlController, decoration: const InputDecoration(hintText: '输入URL')),
                    const SizedBox(height: 12),
                    TextField(controller: nameController, decoration: const InputDecoration(hintText: '站点名称(可选)')),
                    const Divider(),
                    StatefulBuilder(builder: (ctx,setState){
                      return Column(
                        children:[
                          DropdownButtonFormField<String>(
                            value: ua,
                            decoration: const InputDecoration(labelText:'User-Agent',border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value:'chrome',child:Text('Chrome')),
                              DropdownMenuItem(value:'edge',child:Text('Edge')),
                              DropdownMenuItem(value:'firefox',child:Text('Firefox')),
                              DropdownMenuItem(value:'wechat',child:Text('WeChat')),
                              DropdownMenuItem(value:'qq',child:Text('QQ')),
                              DropdownMenuItem(value:'iphone',child:Text('iPhone Safari')),
                              DropdownMenuItem(value:'android',child:Text('Android Chrome')),
                            ],
                            onChanged:(v)=>setState(()=>ua=v!),
                          ),
                          const SizedBox(height:12),
                          CheckboxListTile(value:gps,onChanged:(v)=>setState(()=>gps=v!),title:const Text('GPS定位')),
                          CheckboxListTile(value:camera,onChanged:(v)=>setState(()=>camera=v!),title:const Text('摄像头')),
                          CheckboxListTile(value:clip,onChanged:(v)=>setState(()=>clip=v!),title:const Text('剪贴板')),
                          CheckboxListTile(value:ip,onChanged:(v)=>setState(()=>ip=v!),title:const Text('IP/设备信息')),
                          CheckboxListTile(value:device,onChanged:(v)=>setState(()=>device=v!),title:const Text('设备详细')),],);
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
              ],
            ),
          );
          if (res == true) {
            // 显示进度对话框
            showDialog(context: context, barrierDismissible: false, builder: (_) =>
              Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(children:[const CircularProgressIndicator(), const SizedBox(width:16), const Expanded(child: Text('正在获取并克隆站点...'))]),
                ),
              ));

            // 在后台执行
            Future(() async {
              await SiteService.instance.addSiteFromUrl(
                urlController.text,
                customName: nameController.text.isEmpty?null:nameController.text,
                gps:gps,camera:camera,clip:clip,ip:ip,device:device,userAgent:ua);
            }).whenComplete((){
              Navigator.pop(context); // close progress dialog
              _load();
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _probeString(Site s){
    final list=<String>[];
    if(s.probeGPS)list.add('GPS');
    if(s.probeCamera)list.add('Cam');
    if(s.probeClipboard)list.add('Clip');
    if(s.probeIP||s.probeDevice)list.add('Info');
    return list.isEmpty?'无':list.join(',');
  }

  void _editProbes(Site site) async {
    bool gps=site.probeGPS,camera=site.probeCamera,clip=site.probeClipboard,ip=site.probeIP,device=site.probeDevice;
    final ok=await showDialog<bool>(context:context,builder:(dCtx)=>AlertDialog(
      title: const Text('修改探针'),
      content: StatefulBuilder(builder:(ctx,setState)=>Column(mainAxisSize:MainAxisSize.min,children:[
        CheckboxListTile(value:gps,onChanged:(v)=>setState(()=>gps=v!),title:const Text('GPS定位')),
        CheckboxListTile(value:camera,onChanged:(v)=>setState(()=>camera=v!),title:const Text('摄像头')),
        CheckboxListTile(value:clip,onChanged:(v)=>setState(()=>clip=v!),title:const Text('剪贴板')),
        CheckboxListTile(value:ip,onChanged:(v)=>setState(()=>ip=v!),title:const Text('IP/设备信息')),
        CheckboxListTile(value:device,onChanged:(v)=>setState(()=>device=v!),title:const Text('设备详细')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dCtx,false),child:const Text('取消')),
        TextButton(onPressed:()=>Navigator.pop(dCtx,true),child:const Text('保存'))],));
    if(ok==true){
      site
        ..probeGPS=gps
        ..probeCamera=camera
        ..probeClipboard=clip
        ..probeIP=ip
        ..probeDevice=device;
      await SiteService.instance.updateSite(site);
      _load();
    }
  }

  @override bool get wantKeepAlive => true;

  @override
  void dispose(){
    _debounce?.cancel();
    super.dispose();
  }
}

class _SiteActionSheet extends StatelessWidget {
  const _SiteActionSheet({required this.site});
  final Site site;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('探针设置'),
          onTap: () => Navigator.pop(context, 'probes'),
        ),
        ListTile(
          leading: const Icon(Icons.open_in_browser),
          title: const Text('浏览器打开'),
          onTap: () => Navigator.pop(context, 'browser'),
        ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text('删除'),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ],
    );
  }
}

class _SitePreview extends StatelessWidget {
  const _SitePreview({required this.site});
  final Site site;
  @override
  Widget build(BuildContext context) {
    final port = site.port ?? ServerService.instance.getPort(site.id) ?? 8080;
    final scheme = 'http';
    final usedPort = port;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('$scheme://localhost:$usedPort'));
    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: WebViewWidget(controller: controller),
    );
  }
} 