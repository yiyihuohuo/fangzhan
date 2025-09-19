import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigFileService {
  ConfigFileService._();
  static final ConfigFileService instance = ConfigFileService._();

  Future<Directory> _configDir() async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory(p.join(dir.path, 'frp_configs'));
    await d.create(recursive: true);
    return d;
  }

  Future<List<FileSystemEntity>> listConfigs() async {
    final dir = await _configDir();
    final entities = await dir.list().toList();
    entities.sort((a, b) => a.path.compareTo(b.path));
    return entities.where((e) => e.path.endsWith('.toml')).toList();
  }

  Future<File> createNew() async {
    final dir = await _configDir();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '.').substring(0, 19);
    final file = File(p.join(dir.path, '$ts.toml'));
    await file.writeAsString('');
    return file;
  }

  Future<void> delete(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> rename(File file, String newName) async {
    final newPath = p.join(file.parent.path, newName);
    await file.rename(newPath);
  }

  static const _prefActive = 'active_config_path';

  Future<String?> getActivePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefActive);
  }

  Future<void> setActivePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_prefActive);
    } else {
      await prefs.setString(_prefActive, path);
    }
  }

  static const _prefAutostart = 'frp_autostart';

  Future<bool> isAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutostart) ?? false;
  }

  Future<void> setAutostart(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutostart, enabled);
  }
} 