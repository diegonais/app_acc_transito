import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/remote/remote_gateway.dart';
import 'app.dart';
import 'theme/app_theme.dart';

class OnlineConfiguration {
  const OnlineConfiguration(
      {this.url = const String.fromEnvironment('SUPABASE_URL'),
      this.publicKey =
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')});
  final String url;
  final String publicKey;
  bool get isValid {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty && uri.path != '/' ||
        uri.hasQuery ||
        uri.hasFragment) return false;
    if (publicKey.startsWith('sb_publishable_') && publicKey.length > 20)
      return true;
    // Compatibilidad con anon JWT; rechazar claves privilegiadas por rol.
    try {
      final parts = publicKey.split('.');
      return parts.length == 3 &&
          (jsonDecode(utf8
                      .decode(base64Url.decode(base64Url.normalize(parts[1]))))
                  as Map)['role'] ==
              'anon';
    } catch (_) {
      return false;
    }
  }
}

class ModeSelection extends StatefulWidget {
  const ModeSelection(
      {super.key, this.configuration = const OnlineConfiguration()});
  final OnlineConfiguration configuration;
  @override
  State<ModeSelection> createState() => _ModeSelectionState();
}

class _ModeSelectionState extends State<ModeSelection> {
  bool _loading = false;
  String? _error;
  Widget? _selected;
  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _selected!;
    return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('ACC Tránsito · Modalidad')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _selected = const AccTransitoApp()),
                          child: const Text('LOCAL · SQLite del dispositivo')),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loading ? null : _online,
                          child: Text(_loading
                              ? 'Preparando conexión…'
                              : 'DEFENSA EN LÍNEA · Requiere Internet')),
                      const SizedBox(height: 16),
                      const Text(
                          'En línea se utilizan las cuentas y los informes compartidos de la defensa. Los datos locales permanecen separados.'),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                    ],
                  ))),
        ));
  }

  Future<void> _online() async {
    if (!widget.configuration.isValid) {
      setState(() => _error =
          'Configure SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY mediante --dart-define con una clave publicable o anon.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Inicialización única y diferida: elegir LOCAL nunca inicia Supabase.
      await Supabase.initialize(
          url: widget.configuration.url,
          publishableKey: widget.configuration.publicKey,
          debug: false);
      if (mounted)
        setState(() => _selected = AccTransitoApp(
            remoteGateway: SupabaseGateway(Supabase.instance.client)));
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'No se pudo iniciar el modo en línea. Compruebe la configuración y reintente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
