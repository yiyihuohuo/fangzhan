import 'dart:convert';
import 'dart:async';
import 'database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CaptureService {
  CaptureService._() {
    // 初始加载一次数据，保证进入页面能看到历史记录
    _notify();
  }
  static final CaptureService instance = CaptureService._();

  final _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _cache = [];

  Stream<List<Map<String, dynamic>>> get capturesStream => _streamController.stream;

  void _emit(List<Map<String, dynamic>> data) {
    _cache = data;
    _streamController.add(data);
  }

  Future<void> addCapture({required String type, required Map<String, dynamic> headers, required String body, required String site}) async {
    // SQLite CursorWindow 单行 ~1MB，过大内容将导致异常；超限时只记录长度
    String storedBody=body;
    const maxLen=800000; // 约 0.8MB
    if(storedBody.length>maxLen){
      try{
        final dir=await getExternalStorageDirectory();
        if(dir!=null){
          final saveDir=Directory(p.join(dir.path,'captures','images'));
          await saveDir.create(recursive:true);
          final filePath=p.join(saveDir.path,'img_${DateTime.now().millisecondsSinceEpoch}.bin');
          // attempt decode base64
          try{
            final bytes=base64Decode(storedBody);
            await File(filePath).writeAsBytes(bytes);
          }catch(_){
            await File(filePath).writeAsString(storedBody);
          }
          storedBody='FILE:$filePath';
        }else{
          storedBody='[DATA_TRUNCATED length=${storedBody.length}]';
        }
      }catch(_){
        storedBody='[DATA_TRUNCATED length=${storedBody.length}]';
      }
    }

    final db = await DatabaseHelper.instance.database;
    await db.insert('captures', {
      'time': DateTime.now().millisecondsSinceEpoch,
      'type': type,
      'site': site,
      'headers': jsonEncode(headers),
      'body': storedBody,
    });
    _notify();
  }

  Future<List<Map<String, dynamic>>> fetchCaptures({String? filterType,bool preview=true}) async {
    final db = await DatabaseHelper.instance.database;
    final columns = preview
        ? ['id','time','type','site','headers','substr(body,1,2048) AS body']
        : null; // all columns
    return await db.query(
      'captures',
      columns: columns,
      where: filterType != null ? 'type = ?' : null,
      whereArgs: filterType != null ? [filterType] : null,
      orderBy: 'time DESC',
    );
  }

  Future<void> deleteCapture(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('captures', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<String> exportCapturesPretty() async {
    final list = await fetchCaptures();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(list);
  }

  Future<void> _notify() async {
    _emit(await fetchCaptures(preview:true));
  }

  Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('captures');
    _notify();
  }

  Future<Map<String,dynamic>?> getCapture(int id) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('captures', where:'id=?', whereArgs:[id]);
    if(res.isNotEmpty) return res.first;
    return null;
  }
} 