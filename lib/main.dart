import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'data/app_database.dart';
import 'services/book_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const size = Size(1200, 800);
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: size, minimumSize: Size(900, 600), title: '阅读 - Windows'),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  await AppDatabase.init();
  BookService.instance.registerJsBridge();
  runApp(const LegadoApp());
}
