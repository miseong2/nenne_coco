// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenne_coco/main.dart';

void main() {
  testWidgets('Main screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the main screen title is rendered.
    expect(find.text('낸내코코'), findsOneWidget);
    expect(find.text('infant safety notification system'), findsOneWidget);

    // Verify that the main button is rendered.
    expect(find.text('실시간 영상'), findsOneWidget);
  });
}