import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:route_app_frontend/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RouteApp()));
    await tester.pumpAndSettle();

    expect(find.text('Route App'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
