import 'package:flutter/material.dart';

import '../services/server_service.dart';
import '../services/tunnel_service.dart';
import '../services/site_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    final sites = await SiteService.instance.fetchSites();
    for (final s in sites.where((e) => e.enabled)) {
      await ServerService.instance.startSite(s);
    }
    notifyListeners();
  }

  bool get serverRunning => ServerService.instance.isAnyRunning;
  bool get tunnelConnected => TunnelService.instance.isConnected;
  String? get publicUrl => TunnelService.instance.publicUrl;
  String? _tunnelError;
  String? get tunnelError => _tunnelError;

  Future<void> toggleServer() async {
    final sites = await SiteService.instance.fetchSites();
    if (serverRunning) {
      for (final s in sites) {
        await ServerService.instance.stopSite(s);
      }
    } else {
      for (final s in sites.where((e) => e.enabled)) {
        await ServerService.instance.startSite(s);
      }
    }
    notifyListeners();
  }

  Future<void> toggleTunnel({int? port}) async {
    if(tunnelConnected){
      await TunnelService.instance.stop();
      _tunnelError=null;
    }else{
      try{
        await TunnelService.instance.startFrp(localPort: port);
        _tunnelError=null;
      }catch(e){
        _tunnelError=e.toString();
      }
    }
    notifyListeners();
  }

  Future<List<Site>> fetchSites() => SiteService.instance.fetchSites();
} 