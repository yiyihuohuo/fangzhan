import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:toml/toml.dart';
import 'package:flutter/foundation.dart';

import 'frp_config_service.dart';

class TunnelService {
  final MethodChannel _channel = const MethodChannel('frp_channel');
  final _logController = StreamController<String>.broadcast();
  final List<String> _history = [];
  Stream<String> get logStream => _logController.stream;
  Timer? _logTimer;

  TunnelService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLog') {
        final msg = call.arguments?.toString() ?? '';
        _logController.add(msg);
        _history.add(msg);
        if (_history.length > 500) _history.removeAt(0);
      }
    });
  }

  static final TunnelService instance = TunnelService._();

  bool _connected = false;
  String? _publicUrl;

  bool get isConnected => _connected;
  String? get publicUrl => _publicUrl;

  Future<void> startFrp({int? localPort}) async {
    debugPrint('TunnelService.startFrp invoked');
    // 优先使用用户导入的原始 toml
    final rawToml = await FrpConfigService.instance.getRawToml();

    String serverAddr = '';
    String serverPort = '7000';
    String proto = 'http';
    String remotePort = '';
    String customDomains = '';

    if (rawToml != null && rawToml.trim().isNotEmpty) {
      // 不再解析，直接交给 frpc 自行校验
      try {
        _connected = true;
        _channel.invokeMethod('startFrp', {'config': rawToml});
        _startLogPolling();
      } catch (e) {
        _connected = false;
        rethrow;
      }
      return;
    }

    debugPrint('startFrp fallback path');
    // ====== 旧构造方式 ======
    final cfg = await FrpConfigService.instance.loadConfig();
    serverAddr = cfg['server_addr'] ?? '';
    serverPort = cfg['server_port'] ?? '7000';
    final token = cfg['token'] ?? '';
    remotePort = cfg['remote_port'] ?? '';
    proto = cfg['proto'] ?? 'http';

    // 新增高级参数
    final user = cfg['user'];
    final dnsServer = cfg['dns_server'];
    final tcpMux = (cfg['tcp_mux'] ?? '1') == '1';
    final privilegeMode = (cfg['privilege_mode'] ?? '1') == '1';
    customDomains = cfg['custom_domains'] ?? remotePort; // 兼容旧逻辑
    final useEncryption = (cfg['use_encryption'] ?? '0') == '1';
    final useCompression = (cfg['use_compression'] ?? '0') == '1';
    final localIp = cfg['local_ip'] ?? '127.0.0.1';

    final int lp = localPort ?? int.tryParse(cfg['local_port'] ?? '') ?? 80;

    // 简单校验
    if (serverAddr.isEmpty) {
      throw Exception('FRP 服务器地址不能为空');
    }
    if (remotePort.isEmpty && (customDomains.isEmpty)) {
      throw Exception(proto == 'tcp' ? '远程端口不能为空' : '远程域名 / 子域名不能为空');
    }

    // 先测试网络连通性
    try {
      final s = await Socket.connect(serverAddr, int.parse(serverPort), timeout: const Duration(seconds: 3));
      s.destroy();
    } catch (_) {
      throw Exception('无法连接 FRP 服务器 ($serverAddr:$serverPort)');
    }

    // 2. 构造 toml 内容
    final buffer = StringBuffer();
    buffer.writeln('serverAddr = "$serverAddr"');
    buffer.writeln('serverPort = $serverPort');
    buffer.writeln('tcpMux = $tcpMux');
    buffer.writeln('protocol = "$proto"');
    if (user != null && user.isNotEmpty) buffer.writeln('user = "$user"');
    if (token.isNotEmpty) buffer.writeln('auth.method = "token"\nauth.token = "$token"');
    if (dnsServer != null && dnsServer.isNotEmpty) buffer.writeln('dnsServer = "$dnsServer"');
    buffer.writeln();
    buffer.writeln('[[proxies]]');
    buffer.writeln('name = "app_tunnel"');
    buffer.writeln('privilegeMode = $privilegeMode');
    if (proto == 'tcp') {
      buffer.writeln('type = "tcp"');
      buffer.writeln('localIP = "$localIp"');
      buffer.writeln('localPort = $lp');
      buffer.writeln('remotePort = $remotePort');
      buffer.writeln('useEncryption = $useEncryption');
      buffer.writeln('useCompression = $useCompression');
    } else {
      buffer.writeln('type = "http"');
      if (proto == 'https') buffer.writeln('customDomains = ["$customDomains"]\ntransport.tls.enable = true');
      else buffer.writeln('customDomains = ["$customDomains"]');
      buffer.writeln('localIP = "$localIp"');
      buffer.writeln('localPort = $lp');
      buffer.writeln('useEncryption = $useEncryption');
      buffer.writeln('useCompression = $useCompression');
    }

    final cfgContent = buffer.toString();

    // 3. 调用原生启动
    _connected = true;
    try {
      _channel.invokeMethod('startFrp', {'config': cfgContent}); // 不 await
      debugPrint('invokeMethod startFrp old path sent');
    } catch (_) {}

    // 4. 生成公网 URL
    _publicUrl = _buildPublicUrl(proto, serverAddr, remotePort, customDomains);

    // 开始日志轮询
    _startLogPolling();
  }

  String? _buildPublicUrl(String proto, String serverAddr, String remotePort, String customDomains) {
    if (proto == 'tcp') {
      return 'tcp://$serverAddr:$remotePort';
    } else {
      final scheme = proto == 'https' ? 'https' : 'http';
      final domain = customDomains.isNotEmpty ? customDomains : remotePort;
      if (RegExp(r'^[0-9]+$').hasMatch(domain)) {
        return '$scheme://$serverAddr:$domain';
      } else {
        return '$scheme://$domain';
      }
    }
  }

  Future<void> stop() async {
    _connected = false;
    _publicUrl = null;
    _logTimer?.cancel();
    try {
      _channel.invokeMethod('stop'); // fire and forget
    } catch (_) {}
  }

  void _startLogPolling() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final logs = await _channel.invokeMethod<String>('getLogs');
        if (logs != null && logs.isNotEmpty) {
          for (final line in logs.split("\n")) {
            if (line.isNotEmpty) {
              _logController.add(line);
              _history.add(line);
              if (_history.length > 500) _history.removeAt(0);
            }
          }
        }
      } catch (_) {}
    });
  }

  List<String> get logHistory => List.unmodifiable(_history);
} 