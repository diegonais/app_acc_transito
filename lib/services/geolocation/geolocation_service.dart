import 'package:geolocator/geolocator.dart';

enum GeolocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

class GeolocationResult {
  const GeolocationResult._({
    this.latitude,
    this.longitude,
    this.failure,
    this.detail,
  });

  const GeolocationResult.success({
    required double latitude,
    required double longitude,
  }) : this._(latitude: latitude, longitude: longitude);

  const GeolocationResult.failure(
    GeolocationFailure failure, {
    String? detail,
  }) : this._(failure: failure, detail: detail);

  final double? latitude;
  final double? longitude;
  final GeolocationFailure? failure;
  final String? detail;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get message {
    return switch (failure) {
      GeolocationFailure.serviceDisabled =>
        'El servicio de ubicacion esta desactivado. Puede finalizar el informe sin coordenadas.',
      GeolocationFailure.permissionDenied =>
        'Permiso de ubicacion denegado. Puede finalizar el informe conservando el lugar textual.',
      GeolocationFailure.permissionPermanentlyDenied =>
        'Permiso de ubicacion denegado permanentemente. Habilitelo desde ajustes si necesita registrar coordenadas.',
      GeolocationFailure.unavailable => detail ??
          'No se pudo obtener la ubicacion. Puede finalizar el informe sin coordenadas.',
      null => 'Coordenadas registradas.',
    };
  }
}

class GeolocationService {
  const GeolocationService();

  Future<GeolocationResult> currentCoordinates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GeolocationResult.failure(
          GeolocationFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const GeolocationResult.failure(
          GeolocationFailure.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const GeolocationResult.failure(
          GeolocationFailure.permissionPermanentlyDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeolocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      return GeolocationResult.failure(
        GeolocationFailure.unavailable,
        detail:
            'No se pudo obtener la ubicacion: $error. Puede finalizar el informe sin coordenadas.',
      );
    }
  }
}
