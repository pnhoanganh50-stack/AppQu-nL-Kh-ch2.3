import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'notifications.dart';
import 'screens/home_screen.dart';
import 'security.dart';
import 'theme.dart';
import 'utils.dart';

/// Dùng để mở màn hình chi tiết khi bấm vào thông báo.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  Intl.defaultLocale = 'vi';
  await Security.init();
  await AppPaths.init();
  try {
    await Noti.init();
  } catch (_) {
    // Thông báo lỗi thì app vẫn chạy bình thường.
  }
  runApp(const QuanLyKhachApp());
}

class QuanLyKhachApp extends StatelessWidget {
  const QuanLyKhachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Quản Lý Khách BĐS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
      home: const HomeScreen(),
    );
  }
}
