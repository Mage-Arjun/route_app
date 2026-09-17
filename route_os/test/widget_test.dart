import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:route_app_frontend/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RouteApp()));
    // Login has a deliberately looping ambient animation, so settle a frame
    // window instead of waiting for the widget tree to become fully idle.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('RouteOS'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
