import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisscore/ui/end_of_run.dart';

Widget _card({required int yours, required int theirs, String name = 'SAM'}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 300,
        child: HeadToHead(yours: yours, theirs: theirs, name: name),
      ),
    ),
  );
}

void main() {
  testWidgets('ahead says so, and says who was beaten', (tester) async {
    await tester.pumpWidget(_card(yours: 300, theirs: 120));
    await tester.pump();

    expect(find.text('VS SAM'), findsOneWidget);
    expect(find.text('300 / 120'), findsOneWidget);
    expect(find.text('YOU BEAT SAM'), findsOneWidget);
  });

  testWidgets('behind says by how much, which is the useful part', (
    tester,
  ) async {
    await tester.pumpWidget(_card(yours: 90, theirs: 120));
    await tester.pump();

    expect(find.text('30 SHORT OF SAM'), findsOneWidget);
  });

  testWidgets('level is a dead heat, not a loss', (tester) async {
    await tester.pumpWidget(_card(yours: 120, theirs: 120));
    await tester.pump();

    expect(find.text('DEAD HEAT'), findsOneWidget);
    expect(find.textContaining('SHORT'), findsNothing);
  });

  testWidgets('a rival who never chose a name is still somebody', (
    tester,
  ) async {
    await tester.pumpWidget(_card(yours: 10, theirs: 120, name: ''));
    await tester.pump();

    expect(find.text('VS THEM'), findsOneWidget);
    expect(find.text('110 SHORT OF THEM'), findsOneWidget);
  });

  testWidgets('a rival who scored nothing does not divide by zero', (
    tester,
  ) async {
    await tester.pumpWidget(_card(yours: 0, theirs: 0));
    await tester.pump();

    expect(find.text('DEAD HEAT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
