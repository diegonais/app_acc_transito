import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/speech/dictation_service.dart';

class DescriptionDictationField extends StatefulWidget {
  const DescriptionDictationField(
      {super.key,
      required this.controller,
      this.service = const DictationService()});
  final TextEditingController controller;
  final DictationService service;

  @override
  State<DescriptionDictationField> createState() =>
      _DescriptionDictationFieldState();
}

class _DescriptionDictationFieldState extends State<DescriptionDictationField> {
  bool _listening = false;
  String? _message;
  int _session = 0;

  Future<void> _cancel() async {
    _session++;
    if (mounted) setState(() => _listening = false);
    try {
      await widget.service.cancel();
    } catch (_) {/* Sin audio pendiente. */}
  }

  @override
  void dispose() {
    _session++;
    unawaited(widget.service.cancel().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _listen() async {
    final session = ++_session;
    final previous = widget.controller.text;
    FocusScope.of(context).unfocus();
    setState(() {
      _listening = true;
      _message = null;
    });
    try {
      final text = (await widget.service.listen())?.trim();
      if (!mounted || session != _session) return;
      if (text != null && text.isNotEmpty) {
        final combined =
            previous.trim().isEmpty ? text : '${previous.trimRight()}\n$text';
        widget.controller.value = TextEditingValue(
            text: combined,
            selection: TextSelection.collapsed(offset: combined.length));
        _message =
            'Texto añadido. Revise y corrija la descripción antes de continuar.';
      } else {
        _message = 'No se añadió texto. Puede volver a dictar o escribir.';
      }
    } on PlatformException catch (error) {
      if (!mounted || session != _session) return;
      _message = switch (error.code) {
        'permission' =>
          'Permita el acceso al micrófono en Ajustes para dictar. Puede seguir escribiendo.',
        'unavailable' =>
          'Dictado local no disponible. Requiere Android 12 o superior y reconocimiento de voz local en español. Puede seguir escribiendo.',
        'language_missing' ||
        'recognition_12' ||
        'recognition_13' =>
          'Falta el idioma español para dictado sin conexión. Descárguelo en los ajustes de reconocimiento de voz del teléfono. Puede seguir escribiendo.',
        'recognition_6' ||
        'recognition_7' =>
          'No se escucharon palabras. Pulse Dictar descripción y hable de nuevo cerca del micrófono.',
        _ =>
          'No se pudo reconocer la voz. Compruebe el idioma español del dispositivo o vuelva a intentarlo. Su texto se conserva.',
      };
    } catch (_) {
      if (!mounted || session != _session) return;
      _message = 'Dictado no disponible. Puede seguir escribiendo.';
    } finally {
      if (mounted && session == _session) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
              controller: widget.controller,
              minLines: 5,
              maxLines: 8,
              readOnly: _listening,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo obligatorio.'
                  : null),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _listening
                    ? () async {
                        try {
                          await widget.service.stop();
                        } catch (_) {
                          await _cancel();
                        }
                      }
                    : _listen,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(
                    _listening ? 'Terminar dictado' : 'Dictar descripción')),
            if (_listening)
              TextButton(
                  onPressed: _cancel, child: const Text('Cancelar dictado')),
          ]),
          Text(_listening
              ? 'Escuchando… Hable en español.'
              : _message ??
                  'Puede escribir o dictar por partes y luego editar el texto. El audio no se guarda.'),
          const SizedBox(height: 12),
        ],
      );
}
