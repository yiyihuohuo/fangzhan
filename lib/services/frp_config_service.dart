import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FrpConfigService {
  static final FrpConfigService instance = FrpConfigService._();
  FrpConfigService._();

  static const _table = 'frp_config';

  Future<void> saveConfig({
    required String serverAddr,
    required int serverPort,
    required String token,
    required String proto,
    required String remotePort,
    String? user,
    String? dnsServer,
    bool tcpMux = true,
    String protocol = 'tcp',
    bool privilegeMode = true,
    String? localIp,
    int? localPort,
    String? customDomains,
    bool useEncryption = false,
    bool useCompression = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    batch.insert(_table, {'key': 'server_addr', 'value': serverAddr}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'server_port', 'value': serverPort.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'token', 'value': token}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'proto', 'value': proto}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'remote_port', 'value': remotePort}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'use_subdomain', 'value': '0'}, conflictAlgorithm: ConflictAlgorithm.replace);

    // 新增字段保存
    if (user != null) batch.insert(_table, {'key': 'user', 'value': user}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (dnsServer != null) batch.insert(_table, {'key': 'dns_server', 'value': dnsServer}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'tcp_mux', 'value': tcpMux ? '1' : '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'protocol', 'value': protocol}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'privilege_mode', 'value': privilegeMode ? '1' : '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (localIp != null) batch.insert(_table, {'key': 'local_ip', 'value': localIp}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (localPort != null) batch.insert(_table, {'key': 'local_port', 'value': localPort.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (customDomains != null) batch.insert(_table, {'key': 'custom_domains', 'value': customDomains}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'use_encryption', 'value': useEncryption ? '1' : '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(_table, {'key': 'use_compression', 'value': useCompression ? '1' : '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  }

  Future<Map<String, String>> loadConfig() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(_table);
    final map = { for (final row in res) (row['key'] as String): (row['value'] as String) };

    // 如果数据库为空，则尝试解析 frp.ini
    if (map.isEmpty || !(map.containsKey('server_addr'))) {
      final iniMap = await _parseIni();
      map.addAll(iniMap);
    }
    return map;
  }

  Future<String?> _getValue(String key) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(_table, where: 'key=?', whereArgs: [key], limit: 1);
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return null;
  }

  Future<String?> get serverAddr async => await _getValue('server_addr');
  Future<int?> get serverPort async {
    final v = await _getValue('server_port');
    return v != null ? int.tryParse(v) : null;
  }
  Future<String?> get token async => await _getValue('token');
  Future<String?> get proto async => await _getValue('proto');
  Future<String?> get remotePort async => await _getValue('remote_port');
  Future<bool> get useSubdomain async => (await _getValue('use_subdomain'))=='1';

  Future<Map<String,String>> _parseIni() async {
    try{
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path,'frp.ini'));
      if(!await file.exists()) return {};
      final lines = await file.readAsLines();
      final res = <String,String>{};
      for(final l in lines){
        final idx = l.indexOf('=');
        if(idx==-1) continue;
        final key = l.substring(0,idx).trim();
        final value = l.substring(idx+1).trim();
        res[key]=value;
      }
      return {
        if(res['server_addr']!=null) 'server_addr':res['server_addr']!,
        if(res['server_port']!=null) 'server_port':res['server_port']!,
        if(res['token']!=null) 'token':res['token']!,
        if(res['remote_port']!=null) 'remote_port':res['remote_port']!,
        if(res['subdomain']!=null) 'remote_port':res['subdomain']!,
        if(res['custom_domains']!=null) 'remote_port':res['custom_domains']!,
        if(res['type']!=null) 'proto':res['type']!,
      };
    }catch(_){
      return {};
    }
  }

  // 保存原始 toml 内容
  Future<void> saveRawToml(String toml) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(_table, {'key': 'raw_toml', 'value': toml}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getRawToml() => _getValue('raw_toml');
} 