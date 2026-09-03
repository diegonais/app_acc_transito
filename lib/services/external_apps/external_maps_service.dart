import 'package:url_launcher/url_launcher.dart';

class ExternalMapsService {
  const ExternalMapsService();

  Uri coordinatesUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude(Lugar%20del%20hecho)',
    );
  }

  Future<bool> openCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final geoUri = coordinatesUri(latitude: latitude, longitude: longitude);
    if (await canLaunchUrl(geoUri)) {
      return launchUrl(geoUri, mode: LaunchMode.externalApplication);
    }

    final webUri = Uri.https(
      'www.openstreetmap.org',
      '/search',
      {'query': '$latitude,$longitude'},
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
