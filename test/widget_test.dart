import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:securescan_final/main.dart';

void main() {
  testWidgets('App launches and shows navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const SecureScanApp());
    await tester.pumpAndSettle();

    expect(find.text('Deepfake Detection'), findsOneWidget);
    expect(find.text('Phishing Detection'), findsOneWidget);
    expect(find.text('Scan History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    expect(find.text('Ready to scan'), findsOneWidget);
  });
}
