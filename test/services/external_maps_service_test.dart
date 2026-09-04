import 'package:app_acc_transito/services/external_apps/external_maps_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('construye URI geo con coordenadas como fuente de verdad', () {
    final uri = const ExternalMapsService().coordinatesUri(
      latitude: -17.783327,
      longitude: -63.182140,
    );

    expect(uri.scheme, 'geo');
    expect(
      uri.toString(),
      'geo:-17.783327,-63.18214?q=-17.783327,-63.18214(Lugar%20del%20hecho)',
    );
  });

  test('construye URI estable para coordenadas cero', () {
    final uri = const ExternalMapsService().coordinatesUri(
      latitude: 0,
      longitude: 0,
    );

    expect(uri.toString(), 'geo:0.0,0.0?q=0.0,0.0(Lugar%20del%20hecho)');
  });
}
