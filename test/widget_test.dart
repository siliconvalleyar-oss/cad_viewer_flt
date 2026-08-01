// Smoke test: la app arranca y muestra la pantalla de inicio.
import 'package:cad_viewer/controllers/cad_view_model.dart';
import 'package:cad_viewer/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('La app arranca y muestra el botón Abrir archivo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CadViewModel(),
        child: const CadViewerApp(),
      ),
    );

    // Espera el splash (500 ms) y la transición.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Abrir archivo'), findsOneWidget);
    expect(find.text('CAD Viewer & Editor'), findsWidgets);
  });
}
