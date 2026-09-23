import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/ledger/application/ledger_controller.dart';

class DaynBookApp extends StatefulWidget {
  const DaynBookApp({super.key});

  @override
  State<DaynBookApp> createState() => _DaynBookAppState();
}

class _DaynBookAppState extends State<DaynBookApp> {
  late final LedgerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LedgerController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دفتر الدين',
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: HomeScreen(controller: _controller),
    );
  }
}
