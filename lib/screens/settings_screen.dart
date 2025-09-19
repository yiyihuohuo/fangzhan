import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/capture_service.dart';
import '../services/site_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _keepAlive=false;
  @override
  void initState(){
    super.initState();
    _loadPrefs();
  }
  Future<void> _loadPrefs() async{
    final prefs=await SharedPreferences.getInstance();
    setState((){
      _keepAlive=prefs.getBool('keep_alive')??false;
    });
    if(_keepAlive){
      NotificationService.instance.showOngoing();
    }
  }
  Future<void> _toggleKeepAlive(bool v) async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool('keep_alive', v);
    setState(()=>_keepAlive=v);
    if(v){
      await NotificationService.instance.showOngoing();
    }else{
      await NotificationService.instance.cancelOngoing();
    }
  }
  Future<void> _clearCache() async{
    final dir=await getTemporaryDirectory();
    try{await dir.delete(recursive:true);}catch(_){}
    if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('缓存已清理')));}  }

  Future<void> _clearAllData() async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('确认删除?'),content:const Text('该操作将删除站点、副本、捕获记录及设置，无法恢复。'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('确定'))]));
    if(ok!=true) return;
    // stops servers
    final sites=await SiteService.instance.fetchSites();
    for(final s in sites){await SiteService.instance.deleteSite(s.id);}    
    await CaptureService.instance.clearAll();
    final prefs=await SharedPreferences.getInstance();
    await prefs.clear();
    await _clearCache();
    if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('数据已清除，重启应用生效')));}  }
    
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: ListView(
        children:[
          const ListTile(title:Text('通用设置')),
          ListTile(
            title: Row(
              children:[
                const Text('后台常驻通知'),
                const SizedBox(width:4),
                IconButton(
                  icon:const Icon(Icons.help_outline,size:18),
                  onPressed:(){
                    showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('作用说明'),content:const Text('开启后将在通知栏显示常驻通知，避免系统在后台杀死应用。'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('知道了'))]));
                  },
                )
              ],
            ),
            trailing:Switch(value:_keepAlive,onChanged:_toggleKeepAlive),
          ),
          const Divider(),
          const ListTile(title:Text('数据存储设置')),
          ListTile(
            title:const Text('清理缓存'),
            onTap:_clearCache,
          ),
          ListTile(
            title:const Text('清除全部数据'),
            onTap:_clearAllData,
          ),
          const Divider(),
          const ListTile(title:Text('关于')),
          const ListTile(
            title:Text('版本'),
            subtitle:Text('v1.0.0'),
          ),
          const ListTile(
            title:Text('开发者'),
            subtitle:Text('huo'),
          ),
          ListTile(
            title:const Text('frp帮助'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl('https://gofrp.org/zh-cn/docs/reference/'),
          ),
          ListTile(
            title:const Text('频道'),
            trailing: const Icon(Icons.telegram),
            onTap: () => _launchUrl('http://127.0.0.1/'),
            //因为写完我写完就放弃了这个项目，导致我连频道都没有做
            //二改的时候可以改成你自己的频道，记得表明原作者
          ),
          ListTile(
            title:const Text('github地址'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl('https://github.com/yiyihuohuo/fangzhan'),
          ),
        ],
      ),
    );
  }
} 