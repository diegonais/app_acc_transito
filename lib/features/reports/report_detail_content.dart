import 'package:flutter/material.dart';

import '../../data/repositories/report_repository.dart';
import '../../services/qr/institutional_qr_service.dart';
import '../../services/maps/simple_sketch_map.dart';
import '../../shared/report_format.dart';
import '../../shared/ui/app_button.dart';
import 'widgets/report_detail_widgets.dart';

/// Ficha de consulta: recibe datos autorizados, sin acceso a persistencia.
class ReportDetailContent extends StatelessWidget {
  const ReportDetailContent(
      {super.key,
      required this.report,
      required this.owner,
      required this.onPdf,
      required this.onMaps,
      this.isGeneratingPdf = false});
  final ReportRecord report;
  final Future<InstitutionalQrPolice> owner;
  final VoidCallback onPdf;
  final VoidCallback onMaps;
  final bool isGeneratingPdf;

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _ReportIdentity(report: report),
              const SizedBox(height: 16),
              AppButton(
                  label: isGeneratingPdf ? 'Generando PDF' : 'Ver informe PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: isGeneratingPdf ? null : onPdf),
              ReportDetailSection(
                  title: 'Datos generales',
                  icon: Icons.assignment_outlined,
                  child: InformationFields(fields: {
                    'EPI / Estación Policial Integral': report.epi,
                    'Fecha y hora de llegada':
                        ReportFormat.dateTime(report.fechaHoraLlegada),
                    'Fecha y hora del hecho':
                        ReportFormat.dateTime(report.fechaHoraHecho),
                    'Naturaleza': report.naturaleza,
                    'Lugar': report.lugar,
                  })),
              ReportDetailSection(
                  title: 'Denunciante',
                  icon: Icons.person_outline,
                  child: ReportRecordCard(
                      label: 'Denunciante',
                      title: ReportFormat.value(report.denuncianteNombre),
                      fields: {
                        'Documento': report.denuncianteDocumento,
                        'Contacto': report.denuncianteContacto
                      })),
              ReportDetailSection(
                  title: 'Descripción del hecho',
                  icon: Icons.notes_outlined,
                  child: SelectableText(ReportFormat.value(report.descripcion),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6))),
              ReportDetailSection(
                  title: 'Condiciones y circunstancias',
                  icon: Icons.fact_check_outlined,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InformationFields(fields: {
                          'Condiciones climáticas': report.condicionesClimaticas
                        }),
                        StatusRow(
                            label: 'Vehículos movidos',
                            value: report.vehiculosMovidos),
                        StatusRow(
                            label: 'Protagonistas presentes',
                            value: report.protagonistasPresentes),
                        const SizedBox(height: 16),
                        InformationFields(fields: {
                          'Testigos': report.testigos,
                          'Efectos personales': report.efectosPersonales
                        }),
                      ])),
              _drivers(),
              _vehicles(),
              _people(),
              ReportDetailSection(
                  title: 'Ubicación del hecho',
                  icon: Icons.location_on_outlined,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InformationFields(fields: {
                          'Lugar': report.lugar,
                          'Latitud': report.latitud?.toStringAsFixed(6),
                          'Longitud': report.longitud?.toStringAsFixed(6)
                        }),
                        const SizedBox(height: 16),
                        if (report.latitud != null &&
                            report.longitud != null) ...[
                          OutlinedButton.icon(
                            onPressed: () => _openMap(context),
                            icon: const Icon(Icons.travel_explore_outlined),
                            label: const Text('Ver mapa cartográfico'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                              onPressed: onMaps,
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Abrir coordenadas en mapas')),
                        ] else
                          const EmptySectionMessage(
                              'No se registraron coordenadas. Se conserva la referencia del lugar.'),
                      ])),
              ReportDetailSection(
                  title: 'Croquis cartográfico',
                  icon: Icons.map_outlined,
                  child: (report.rutaCroquis ?? '').trim().isEmpty
                      ? const EmptySectionMessage('No se registró un croquis.')
                      : ReportImageCard(
                          path: report.rutaCroquis!,
                          title: 'Croquis cartográfico',
                          isSketch: true)),
              ReportDetailSection(
                  title: 'Evidencia fotográfica',
                  icon: Icons.photo_library_outlined,
                  count: report.fotografias.length,
                  child: report.fotografias.isEmpty
                      ? const EmptySectionMessage(
                          'No se registraron fotografías.')
                      : _photos()),
              ReportDetailSection(
                  title: 'Funcionario responsable',
                  icon: Icons.badge_outlined,
                  child: FutureBuilder<InstitutionalQrPolice>(
                      future: owner,
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return const EmptySectionMessage(
                              'No se pudo cargar la identificación del funcionario. Vuelva a abrir el informe para reintentar.');
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator(
                              semanticsLabel: 'Cargando funcionario');
                        return ReportOfficerIdentity(owner: snapshot.data!);
                      })),
            ]),
      )));

  void _openMap(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Ubicación del hecho')),
              body: SafeArea(
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                InformationFields(fields: {
                  'Lugar': report.lugar,
                  'Latitud': report.latitud!.toStringAsFixed(6),
                  'Longitud': report.longitud!.toStringAsFixed(6)
                }),
                const SizedBox(height: 20),
                SimpleSketchMap(
                    latitude: report.latitud!, longitude: report.longitud!),
              ])),
            )));
  }

  Widget _drivers() => ReportDetailSection(
      title: 'Conductores',
      icon: Icons.contact_page_outlined,
      count: report.conductores.length,
      child: report.conductores.isEmpty
          ? const EmptySectionMessage('No se registraron conductores.')
          : Column(children: [
              for (final (i, driver) in report.conductores.indexed)
                ReportRecordCard(
                    label: 'Conductor ${i + 1}',
                    title: driver.nombreCompleto,
                    fields: {
                      'Edad': driver.edad?.toString(),
                      'Licencia': driver.licencia,
                      'Categoría': driver.categoria,
                      'Domicilio': driver.domicilio,
                      'Zona': driver.zona,
                      'Contactos': driver.contactos,
                      'Condición de entrega': driver.condicionEntrega,
                    }),
            ]));

  Widget _vehicles() {
    final drivers = {
      for (final d in report.conductores) d.idConductor: d.nombreCompleto
    };
    return ReportDetailSection(
        title: 'Vehículos',
        icon: Icons.directions_car_outlined,
        count: report.vehiculos.length,
        child: report.vehiculos.isEmpty
            ? const EmptySectionMessage('No se registraron vehículos.')
            : Column(children: [
                for (final (i, vehicle) in report.vehiculos.indexed)
                  ReportRecordCard(
                      label: 'Vehículo ${i + 1}',
                      title: 'Placa ${ReportFormat.value(vehicle.placa)}',
                      fields: {
                        'Marca': vehicle.marca,
                        'Color': vehicle.color,
                        'Tipo': vehicle.tipo,
                        'Servicio': vehicle.servicio,
                        'Conductor relacionado': drivers[vehicle.idConductor],
                      }),
              ]));
  }

  Widget _people() => ReportDetailSection(
      title: 'Personas involucradas',
      icon: Icons.groups_outlined,
      count: report.personas.length,
      child: report.personas.isEmpty
          ? const EmptySectionMessage(
              'No se registraron personas involucradas.')
          : Column(children: [
              for (final (i, person) in report.personas.indexed)
                ReportRecordCard(
                    label:
                        'Persona ${i + 1} · ${ReportFormat.personType(person.tipo)}',
                    title: person.nombre,
                    fields: {
                      'Edad': person.edad?.toString(),
                      'Lugar de evacuación': person.lugarEvacuacion
                    }),
            ]));

  Widget _photos() => LayoutBuilder(builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 440 &&
            MediaQuery.textScalerOf(context).scale(14) < 23;
        final width =
            twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (i, photo) in report.fotografias.indexed)
            SizedBox(
                width: width,
                child: ReportImageCard(
                    path: photo.ruta,
                    title: 'Fotografía ${i + 1} · ${photo.tipo.label}',
                    description:
                        ReportFormat.photoDescription(photo.descripcion))),
        ]);
      });
}

class _ReportIdentity extends StatelessWidget {
  const _ReportIdentity({required this.report});
  final ReportRecord report;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('INFORME DE ACCIÓN DIRECTA',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 16),
            const Text('Número de caso'),
            const SizedBox(height: 4),
            Text(report.numeroCaso,
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              const Chip(
                  avatar: Icon(Icons.lock_outline, size: 18),
                  label: Text('Finalizado')),
              Chip(label: Text(report.isActive ? 'Activo' : 'Inactivo')),
            ]),
            const SizedBox(height: 8),
            Text(
                '${report.fechaHoraHecho != null ? 'Fecha del hecho' : 'Fecha de registro'}\n${ReportFormat.dateTime(report.fechaHoraHecho ?? report.fechaCreacion)}',
                style: const TextStyle(height: 1.5)),
          ])),
    );
  }
}

class ReportOfficerIdentity extends StatefulWidget {
  const ReportOfficerIdentity({super.key, required this.owner});
  final InstitutionalQrPolice owner;
  @override
  State<ReportOfficerIdentity> createState() => _ReportOfficerIdentityState();
}

class _ReportOfficerIdentityState extends State<ReportOfficerIdentity> {
  InstitutionalQrCode? _qr;
  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(ReportOfficerIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner) _generate();
  }

  void _generate() {
    try {
      _qr = const InstitutionalQrService().generateForPolice(widget.owner);
    } on ArgumentError {
      _qr = null;
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ReportRecordCard(
            label: 'Funcionario policial',
            title: widget.owner.nombreCompleto,
            fields: {
              'Grado': widget.owner.grado,
              'Número de placa': widget.owner.numeroPlaca,
              'Unidad': widget.owner.unidad
            }),
        const SizedBox(height: 12),
        Text('QR institucional', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (_qr != null)
          Align(
              alignment: Alignment.centerLeft,
              child: InstitutionalQrView(code: _qr!))
        else
          const EmptySectionMessage(
              'No se pudo generar el QR con la identificación disponible.'),
      ]);
}
