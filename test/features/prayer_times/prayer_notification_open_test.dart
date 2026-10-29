import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_notification_open_host.dart';

void main() {
  testWidgets(
    'a notification tap opens one route and never replaces the reader on normal launch',
    (tester) async {
      final events = StreamController<void>.broadcast(sync: true);
      var requested = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PrayerNotificationOpenHost(
            events: events.stream,
            takeOpen: () async {
              final value = requested;
              requested = false;
              return value;
            },
            destination: (_) => const Scaffold(body: Text('Prayer target')),
            child: const Scaffold(body: Text('Reader')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Prayer target'), findsNothing);
      requested = true;
      events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Prayer target'), findsOneWidget);
      requested = true;
      events.add(null);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Prayer target'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Prayer target'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(events.hasListener, false);
      await events.close();
    },
  );
  testWidgets(
    'unavailable notification host does not prevent the reader from opening',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrayerNotificationOpenHost(
            events: const Stream.empty(),
            takeOpen: () async => throw StateError('unavailable'),
            child: const Scaffold(body: Text('Reader')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reader'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
