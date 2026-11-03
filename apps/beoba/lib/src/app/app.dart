import 'package:domain_data/domain_data.dart' show Glossary;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/domain_providers.dart';
import '../safety/safety_reporter.dart';
import '../widgets/consent_after_result.dart';
import '../widgets/term_sheet.dart';
import 'router.dart';
import 'theme.dart';

class BeobaApp extends ConsumerWidget {
  const BeobaApp({this.reporter = const LoggingSafetyReporter(), super.key});

  final SafetyReporter reporter;

  static const String title = '버바';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: buildBeobaTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // 시스템 글꼴 확대를 받아들이되 상한을 둔다. 2배까지는 레이아웃이 버틴다.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 1,
          maxScaleFactor: 2,
          child: SafetyReporterScope(
            reporter: reporter,
            // 용어집을 여기 한 번 깔면 아래 모든 SafeText 가 찾아 쓴다.
            // 아직 로드 전이면 빈 용어집이라 밑줄이 안 그려질 뿐이다.
            child: GlossaryScope(
              glossary: ref.watch(domainBundleProvider).value?.glossary ??
                  const Glossary(),
              // 집계 동의는 첫 결과를 떠나 도착한 화면에서 묻는다(289).
              child: ConsentAfterResult(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
