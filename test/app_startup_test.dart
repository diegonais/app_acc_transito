import 'package:app_acc_transito/app/app.dart';
import 'package:app_acc_transito/app/routes/app_routes.dart';
import 'package:app_acc_transito/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts with institutional logo and base navigation',
      (tester) async {
    await tester.pumpWidget(const AccTransitoApp());
    await tester.pump();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Login pendiente'), findsOneWidget);

    await tester.tap(find.text('Validar ruta base'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Dashboard pendiente'), findsOneWidget);
  });

  testWidgets('unknown routes resolve to login placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        initialRoute: '/ruta-no-registrada',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Login pendiente'), findsOneWidget);
  });
}
