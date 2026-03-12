import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart' hide MenuItem;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants.dart';

class DesktopService with WindowListener, TrayListener {
  static DesktopService? _instance;
  static HttpServer? _instanceServer;
  static const int _instancePort = 53683;

  /// Callback when window is hidden to tray (for locking vault)
  static void Function()? onWindowHidden;

  DesktopService._();

  /// Ensures only one instance of the app is running on Windows.
  static Future<bool> ensureSingleInstance() async {
    if (!Platform.isWindows) return true;
    try {
      _instanceServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4, _instancePort,
      );
      _instanceServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/show') {
          await windowManager.show();
          await windowManager.focus();
        }
        request.response.write('OK');
        await request.response.close();
      });
      return true;
    } catch (_) {
      // Another instance is running, wake it up
      try {
        final client = HttpClient();
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$_instancePort/show'),
        );
        await req.close();
      } catch (_) {}
      return false;
    }
  }

  static Future<void> init() async {
    if (!Platform.isWindows) return;

    _instance = DesktopService._();

    // Window Manager
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appName,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Intercept close to minimize to tray
    await windowManager.setPreventClose(true);
    windowManager.addListener(_instance!);

    // Launch at Startup
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
    } catch (_) {}

    // System Tray using tray_manager
    await _initTray();
  }

  // =============== WINDOW LISTENER ===============
  @override
  void onWindowClose() async {
    // Hide window to tray instead of closing
    await windowManager.hide();
    // Lock vault immediately for security
    onWindowHidden?.call();
  }

  // =============== TRAY LISTENER ===============
  @override
  void onTrayIconMouseDown() {
    // Left click on tray icon -> show the window
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Right click on tray icon -> show context menu
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide_window':
        await windowManager.hide();
        break;
      case 'exit_app':
        await windowManager.setPreventClose(false);
        await windowManager.close();
        exit(0);
    }
  }

  // =============== TRAY INITIALIZATION ===============
  static Future<void> _initTray() async {
    // tray_manager requires .ico for Windows!
    // We'll use the app_icon.ico from windows/runner/resources
    // But in release mode, we need absolute path

    final String exeDir = File(Platform.resolvedExecutable).parent.path;

    // Try to find .ico file first (best for Windows tray)
    final List<String> iconCandidates = [
      '$exeDir\\data\\flutter_assets\\assets\\logo\\OneShield_logo.ico',
      '$exeDir\\data\\flutter_assets\\assets\\logo\\OneShield_logo.png',
      'assets/logo/OneShield_logo.png',
    ];

    String iconPath = 'assets/logo/OneShield_logo.png'; // default fallback
    for (final candidate in iconCandidates) {
      if (await File(candidate).exists()) {
        iconPath = candidate;
        break;
      }
    }

    try {
      await trayManager.setIcon(iconPath);

      final menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Show OneShield'),
          MenuItem(key: 'hide_window', label: 'Hide to Tray'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Exit App'),
        ],
      );
      await trayManager.setContextMenu(menu);
      trayManager.addListener(_instance!);
    } catch (e) {
      debugPrint('Tray Manager init error: $e');
    }
  }

  // =============== AUTO START ===============
  static Future<void> setAutoStart(bool enabled) async {
    if (!Platform.isWindows) return;
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  static Future<bool> isAutoStartEnabled() async {
    if (!Platform.isWindows) return false;
    return await launchAtStartup.isEnabled();
  }
}
