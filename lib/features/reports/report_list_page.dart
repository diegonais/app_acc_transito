import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/routes/app_routes.dart';
import '../../data/repositories/report_repository.dart';
import '../../services/external_apps/external_maps_service.dart';
import '../../services/geolocation/geolocation_service.dart';
import '../../services/maps/map_snapshot_service.dart';
import '../../services/maps/simple_sketch_map.dart';
import '../../services/media/evidence_media_service.dart';
import '../../services/media/evidence_photo.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_state_view.dart';
import '../auth/application/auth_scope.dart';
import '../auth/domain/app_role.dart';
import '../auth/domain/authenticated_user.dart';
import 'application/report_controller.dart';

class ReportListPage extends StatefulWidget {
  ReportListPage({
    super.key,
    required this.controller,
    GeolocationService? geolocationService,
    MapSnapshotService? mapSnapshotService,
    ExternalMapsService? externalMapsService,
    EvidenceMediaService? evidenceMediaService,
  })  : geolocationService = geolocationService ?? const GeolocationService(),
        mapSnapshotService = mapSnapshotService ?? const MapSnapshotService(),
        externalMapsService =
            externalMapsService ?? const ExternalMapsService(),
        evidenceMediaService = evidenceMediaService ?? EvidenceMediaService();

  final ReportController controller;
  final GeolocationService geolocationService;
  final MapSnapshotService mapSnapshotService;
  final ExternalMapsService externalMapsService;
  final EvidenceMediaService evidenceMediaService;

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).currentUser;
      if (user != null) {
        widget.controller.load(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const SizedBox.shrink();
    }

    return AppScaffoldShell(
      title: 'Informes',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => widget.controller.load(user),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          if (controller.isLoading && controller.reports.isEmpty) {
            return const Center(
              child: AppLoadingState(message: 'Cargando informes'),
            );
          }
          final error = controller.errorMessage;
          if (error != null && controller.reports.isEmpty) {
            return AppErrorState(
              title: 'No se pudo cargar',
              message: error,
              onRetry: () => controller.load(user),
            );
          }
          if (controller.reports.isEmpty) {
            return _EmptyReports(
              isPolice: user.isPolice,
              onCreate: () => _openForm(user),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.reports.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ReportHeader(
                  user: user,
                  onCreate: () => _openForm(user),
                );
              }
              final report = controller.reports[index - 1];
              return _ReportTile(
                report: report,
                canInactivate: user.role == AppRole.admin,
                onOpen: () => _openDetail(user, report.idInforme),
                onInactivate: () => _confirmInactivate(user, report),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openForm(AuthenticatedUser user) async {
    if (!user.isPolice) {
      return;
    }
    final result = await Navigator.of(context).push<FinalizedReport>(
      MaterialPageRoute<FinalizedReport>(
        builder: (_) => DirectActionReportFormPage(
          controller: widget.controller,
          actor: user,
          geolocationService: widget.geolocationService,
          mapSnapshotService: widget.mapSnapshotService,
          externalMapsService: widget.externalMapsService,
          evidenceMediaService: widget.evidenceMediaService,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Informe finalizado: ${result.numeroCaso}.')),
    );
    await _openDetail(user, result.idInforme);
  }

  Future<void> _openDetail(AuthenticatedUser user, int idInforme) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailPage(
          controller: widget.controller,
          actor: user,
          idInforme: idInforme,
          externalMapsService: widget.externalMapsService,
        ),
      ),
    );
    if (mounted) {
      await widget.controller.load(user);
    }
  }

  Future<void> _confirmInactivate(
    AuthenticatedUser user,
    ReportRecord report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar informe'),
        content: Text(
          'El informe ${report.numeroCaso} dejara de mostrarse en la '
          'aplicacion. No se borrara su contenido ni sus relaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.controller.inactivate(
        actor: user,
        idInforme: report.idInforme,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe inactivo.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.user, required this.onCreate});

  final AuthenticatedUser user;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            user.isAdmin ? 'Informes activos del dispositivo' : 'Mis informes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (user.isPolice)
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Nuevo'),
          ),
      ],
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({required this.isPolice, required this.onCreate});

  final bool isPolice;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppEmptyState(
              title: 'Sin informes activos',
              message: 'No existen informes visibles para esta sesion.',
              icon: Icons.assignment_outlined,
            ),
            if (isPolice) ...[
              const SizedBox(height: 20),
              AppButton(
                label: 'Registrar informe',
                icon: Icons.note_add_outlined,
                onPressed: onCreate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.canInactivate,
    required this.onOpen,
    required this.onInactivate,
  });

  final ReportRecord report;
  final bool canInactivate;
  final VoidCallback onOpen;
  final VoidCallback onInactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.numeroCaso,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(report.naturaleza ?? 'Sin naturaleza'),
                        Text(report.lugar ?? 'Sin lugar'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (canInactivate) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onInactivate,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Inactivar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DirectActionReportFormPage extends StatefulWidget {
  const DirectActionReportFormPage({
    super.key,
    required this.controller,
    required this.actor,
    required this.geolocationService,
    required this.mapSnapshotService,
    required this.externalMapsService,
    required this.evidenceMediaService,
  });

  final ReportController controller;
  final AuthenticatedUser actor;
  final GeolocationService geolocationService;
  final MapSnapshotService mapSnapshotService;
  final ExternalMapsService externalMapsService;
  final EvidenceMediaService evidenceMediaService;

  @override
  State<DirectActionReportFormPage> createState() =>
      _DirectActionReportFormPageState();
}

class _DirectActionReportFormPageState
    extends State<DirectActionReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _mapBoundaryKey = GlobalKey();
  final _epi = TextEditingController();
  final _llegada = TextEditingController();
  final _hecho = TextEditingController();
  final _naturaleza = TextEditingController();
  final _lugar = TextEditingController();
  final _denuncianteNombre = TextEditingController();
  final _denuncianteDocumento = TextEditingController();
  final _denuncianteContacto = TextEditingController();
  final _descripcion = TextEditingController();
  final _condicionesClimaticas = TextEditingController();
  final _testigos = TextEditingController();
  final _efectosPersonales = TextEditingController();
  final _latitud = TextEditingController();
  final _longitud = TextEditingController();
  final _rutaCroquis = TextEditingController();
  final _conductores = <DriverInput>[];
  final _vehiculos = <VehicleInput>[];
  final _personas = <PersonInput>[];
  final _fotografias = <PhotoInput>[];
  DateTime? _fechaHoraLlegada;
  DateTime? _fechaHoraHecho;
  bool? _vehiculosMovidos;
  bool? _protagonistasPresentes;
  bool _isSubmitting = false;
  bool _isLocating = false;
  bool _isCapturingSketch = false;
  bool _isPickingPhoto = false;
  String? _errorMessage;
  String? _geoMessage;
  String? _mapMessage;
  String? _photoMessage;

  @override
  void dispose() {
    _epi.dispose();
    _llegada.dispose();
    _hecho.dispose();
    _naturaleza.dispose();
    _lugar.dispose();
    _denuncianteNombre.dispose();
    _denuncianteDocumento.dispose();
    _denuncianteContacto.dispose();
    _descripcion.dispose();
    _condicionesClimaticas.dispose();
    _testigos.dispose();
    _efectosPersonales.dispose();
    _latitud.dispose();
    _longitud.dispose();
    _rutaCroquis.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_draft.hasData,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _cancel();
      },
      child: AppScaffoldShell(
        title: 'Informe de Accion Directa',
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: 'Datos generales',
                children: [
                  _field(_epi, 'EPI / Estacion Policial Integral'),
                  _dateField(
                    controller: _llegada,
                    label: 'Fecha y hora de llegada',
                    value: _fechaHoraLlegada,
                    onChanged: (value) => setState(() {
                      _fechaHoraLlegada = value;
                      _llegada.text = _formatDateTime(value);
                    }),
                  ),
                  _dateField(
                    controller: _hecho,
                    label: 'Fecha y hora del hecho',
                    value: _fechaHoraHecho,
                    onChanged: (value) => setState(() {
                      _fechaHoraHecho = value;
                      _hecho.text = _formatDateTime(value);
                    }),
                  ),
                  _field(_naturaleza, 'Naturaleza'),
                  _field(_lugar, 'Lugar'),
                ],
              ),
              _Section(
                title: 'Denunciante',
                children: [
                  _field(_denuncianteNombre, 'Denunciante'),
                  _field(
                    _denuncianteDocumento,
                    'Documento del denunciante',
                    required: false,
                  ),
                  _field(_denuncianteContacto, 'Contacto del denunciante'),
                ],
              ),
              _Section(
                title: 'Descripcion y condiciones',
                children: [
                  _field(_descripcion, 'Descripcion', maxLines: 5),
                  _field(_condicionesClimaticas, 'Condiciones climaticas'),
                  _boolChoice(
                    label: 'Vehiculos movidos',
                    value: _vehiculosMovidos,
                    onChanged: (value) => setState(() {
                      _vehiculosMovidos = value;
                    }),
                  ),
                  _boolChoice(
                    label: 'Protagonistas presentes',
                    value: _protagonistasPresentes,
                    onChanged: (value) => setState(() {
                      _protagonistasPresentes = value;
                    }),
                  ),
                  _field(
                    _testigos,
                    'Testigos',
                    helperText: 'Use No existe cuando corresponda.',
                  ),
                  _field(
                    _efectosPersonales,
                    'Efectos personales',
                    helperText: 'Use No aplica cuando corresponda.',
                  ),
                ],
              ),
              _Section(
                title: 'Coordenadas y croquis',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLocating ? null : _locateIncident,
                        icon: _isLocating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_outlined),
                        label: Text(
                          _isLocating
                              ? 'Obteniendo ubicacion'
                              : 'Obtener ubicacion',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _hasCoordinates
                            ? () => _openCoordinatesExternally(
                                  _currentLatitude!,
                                  _currentLongitude!,
                                )
                            : null,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Abrir en mapas'),
                      ),
                    ],
                  ),
                  if (_geoMessage != null) ...[
                    const SizedBox(height: 8),
                    _InlineNotice(message: _geoMessage!),
                  ],
                  const SizedBox(height: 12),
                  _field(
                    _latitud,
                    'Latitud',
                    required: false,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateOptionalDouble,
                  ),
                  _field(
                    _longitud,
                    'Longitud',
                    required: false,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateOptionalDouble,
                  ),
                  _field(
                    _rutaCroquis,
                    'Ruta de croquis',
                    required: false,
                    readOnly: true,
                  ),
                  if (_hasCoordinates) ...[
                    RepaintBoundary(
                      key: _mapBoundaryKey,
                      child: SimpleSketchMap(
                        latitude: _currentLatitude!,
                        longitude: _currentLongitude!,
                        onTileErrorChanged: (hasError) {
                          if (mounted) {
                            setState(() {
                              _mapMessage = hasError
                                  ? 'La cartografia no cargo correctamente. Las coordenadas se conservan y el informe puede finalizarse.'
                                  : null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mover el mapa solo cambia el encuadre; las coordenadas registradas no se modifican.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_mapMessage != null) ...[
                      const SizedBox(height: 8),
                      _InlineNotice(message: _mapMessage!),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isCapturingSketch ? null : _captureSketchMap,
                      icon: _isCapturingSketch
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: Text(
                        _isCapturingSketch
                            ? 'Preparando croquis'
                            : 'Preparar PNG para PDF',
                      ),
                    ),
                  ] else
                    const _InlineNotice(
                      message:
                          'Sin coordenadas registradas. Puede finalizar el informe conservando el lugar textual.',
                    ),
                ],
              ),
              _Section(
                title: 'Fotografias y archivos',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isPickingPhoto
                            ? null
                            : () => _addPhotoFromCamera(),
                        icon: _isPickingPhoto
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camara'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isPickingPhoto
                            ? null
                            : () => _addPhotosFromGallery(),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeria'),
                      ),
                    ],
                  ),
                  if (_photoMessage != null) ...[
                    const SizedBox(height: 8),
                    _InlineNotice(message: _photoMessage!),
                  ],
                  const SizedBox(height: 12),
                  if (_fotografias.isEmpty)
                    const Text('No existen fotografias agregadas.')
                  else
                    _PhotoGrid(
                      photos: _fotografias,
                      onCategoryChanged: (index, category) => setState(() {
                        _fotografias[index] = _fotografias[index].copyWith(
                          tipo: category,
                        );
                      }),
                      onRemove: _removePhoto,
                    ),
                ],
              ),
              _RelationSection(
                title: 'Conductores',
                emptyText: 'No existen conductores registrados.',
                count: _conductores.length,
                onAdd: _addDriver,
                itemBuilder: (index) {
                  final driver = _conductores[index];
                  return _EditableSummary(
                    title: driver.nombreCompleto,
                    subtitle: [
                      'Licencia: ${driver.licencia}',
                      'Categoria: ${driver.categoria}',
                      'Contactos: ${driver.contactos}',
                    ].join(' / '),
                    onTap: () => _editDriver(index),
                    onDelete: () => _removeDriver(index),
                  );
                },
              ),
              _RelationSection(
                title: 'Vehiculos',
                emptyText: 'No existen vehiculos registrados.',
                count: _vehiculos.length,
                onAdd: _addVehicle,
                itemBuilder: (index) {
                  final vehicle = _vehiculos[index];
                  return _EditableSummary(
                    title: vehicle.placa ?? 'Sin placa',
                    subtitle: [
                      vehicle.marca,
                      vehicle.color,
                      vehicle.tipo,
                      vehicle.servicio,
                    ].whereType<String>().join(' / '),
                    onTap: () => _editVehicle(index),
                    onDelete: () => setState(() {
                      _vehiculos.removeAt(index);
                    }),
                  );
                },
              ),
              _RelationSection(
                title: 'Personas involucradas',
                emptyText: 'No existen personas involucradas registradas.',
                count: _personas.length,
                onAdd: _addPerson,
                itemBuilder: (index) {
                  final person = _personas[index];
                  return _EditableSummary(
                    title: person.nombre,
                    subtitle: '${person.tipo} / Edad: ${person.edad}',
                    onTap: () => _editPerson(index),
                    onDelete: () => setState(() {
                      _personas.removeAt(index);
                    }),
                  );
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: _isSubmitting ? 'Finalizando' : 'Finalizar informe',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _isSubmitting ? null : _finalize,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Cancelar',
                icon: Icons.close_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: _isSubmitting ? null : _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  DirectActionReportDraft get _draft {
    return DirectActionReportDraft(
      epi: _epi.text,
      fechaHoraLlegada: _fechaHoraLlegada,
      fechaHoraHecho: _fechaHoraHecho,
      naturaleza: _naturaleza.text,
      lugar: _lugar.text,
      denuncianteNombre: _denuncianteNombre.text,
      denuncianteDocumento: _denuncianteDocumento.text,
      denuncianteContacto: _denuncianteContacto.text,
      descripcion: _descripcion.text,
      condicionesClimaticas: _condicionesClimaticas.text,
      vehiculosMovidos: _vehiculosMovidos,
      protagonistasPresentes: _protagonistasPresentes,
      testigos: _testigos.text,
      efectosPersonales: _efectosPersonales.text,
      latitud: _parseOptionalDouble(_latitud.text),
      longitud: _parseOptionalDouble(_longitud.text),
      rutaCroquis: _rutaCroquis.text,
      conductores: List.unmodifiable(_conductores),
      vehiculos: List.unmodifiable(_vehiculos),
      personas: List.unmodifiable(_personas),
      fotografias: List.unmodifiable(_fotografias),
    );
  }

  bool get _hasCoordinates =>
      _currentLatitude != null && _currentLongitude != null;

  double? get _currentLatitude => _tryParseOptionalDouble(_latitud.text);

  double? get _currentLongitude => _tryParseOptionalDouble(_longitud.text);

  Future<void> _finalize() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      if (_hasCoordinates && _rutaCroquis.text.trim().isEmpty) {
        await _captureSketchMap(showSuccessMessage: false);
      }
      final finalized = await widget.controller.finalize(
        actor: widget.actor,
        draft: _draft,
        persistPhotosForCase:
            widget.evidenceMediaService.persistPhotosForReport,
        cleanupPersistedPhotos:
            widget.evidenceMediaService.cleanupPersistentPhotos,
      );
      if (mounted) {
        Navigator.of(context).pop(finalized);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _locateIncident() async {
    setState(() {
      _isLocating = true;
      _geoMessage = null;
      _errorMessage = null;
    });
    final result = await widget.geolocationService.currentCoordinates();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLocating = false;
      _geoMessage = result.message;
      if (result.hasCoordinates) {
        _latitud.text = result.latitude!.toStringAsFixed(7);
        _longitud.text = result.longitude!.toStringAsFixed(7);
        _rutaCroquis.clear();
        _mapMessage = null;
      }
    });
  }

  Future<void> _captureSketchMap({bool showSuccessMessage = true}) async {
    if (!_hasCoordinates) {
      setState(() {
        _mapMessage =
            'No hay coordenadas para preparar el croquis. El informe puede finalizarse sin PNG.';
      });
      return;
    }
    setState(() {
      _isCapturingSketch = true;
      _mapMessage = null;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final context = _mapBoundaryKey.currentContext;
      final boundary = context?.findRenderObject() as RenderRepaintBoundary?;
      final path = await widget.mapSnapshotService.saveBoundaryAsPng(
        boundary,
        fileNamePrefix: 'croquis_${widget.actor.requiredPoliceId}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (path == null) {
          _mapMessage =
              'No se pudo preparar el PNG del croquis. El informe puede finalizarse conservando las coordenadas.';
        } else {
          _rutaCroquis.text = path;
          _mapMessage = showSuccessMessage
              ? 'Croquis PNG preparado para PDF.'
              : _mapMessage;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapMessage =
            'No se pudo preparar el PNG del croquis: $error. El informe puede finalizarse conservando las coordenadas.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingSketch = false;
        });
      }
    }
  }

  Future<void> _openCoordinatesExternally(
    double latitude,
    double longitude,
  ) async {
    final opened = await widget.externalMapsService.openCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se encontro una aplicacion compatible de mapas.'),
      ),
    );
  }

  Future<void> _cancel() async {
    if (!_draft.hasData) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar informe'),
        content: const Text(
          'La informacion ingresada no esta guardada y se perdera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.evidenceMediaService.cleanupTemporaryPhotos(_fotografias);
      _clearDraft();
      Navigator.of(context).pop();
    }
  }

  void _clearDraft() {
    _epi.clear();
    _llegada.clear();
    _hecho.clear();
    _naturaleza.clear();
    _lugar.clear();
    _denuncianteNombre.clear();
    _denuncianteDocumento.clear();
    _denuncianteContacto.clear();
    _descripcion.clear();
    _condicionesClimaticas.clear();
    _testigos.clear();
    _efectosPersonales.clear();
    _latitud.clear();
    _longitud.clear();
    _rutaCroquis.clear();
    _conductores.clear();
    _vehiculos.clear();
    _personas.clear();
    _fotografias.clear();
    _fechaHoraLlegada = null;
    _fechaHoraHecho = null;
    _vehiculosMovidos = null;
    _protagonistasPresentes = null;
    _photoMessage = null;
  }

  Future<void> _addPhotoFromCamera() async {
    await _pickPhotos(() async {
      final photo = await widget.evidenceMediaService.takePhoto();
      return photo == null ? const <PhotoInput>[] : [photo];
    });
  }

  Future<void> _addPhotosFromGallery() async {
    await _pickPhotos(widget.evidenceMediaService.pickFromGallery);
  }

  Future<void> _pickPhotos(Future<List<PhotoInput>> Function() picker) async {
    setState(() {
      _isPickingPhoto = true;
      _photoMessage = null;
      _errorMessage = null;
    });
    try {
      final photos = await picker();
      if (!mounted) {
        return;
      }
      setState(() {
        _fotografias.addAll(photos);
        _photoMessage = photos.isEmpty
            ? 'No se seleccionaron fotografias.'
            : 'Fotografias agregadas al formulario. Se guardaran definitivamente al finalizar.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _photoMessage =
            'No se pudo acceder a la camara o galeria: $error. Revise permisos del dispositivo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  Future<void> _removePhoto(int index) async {
    final removed = _fotografias.removeAt(index);
    setState(() {
      _photoMessage = 'Fotografia quitada del formulario.';
    });
    await widget.evidenceMediaService.cleanupTemporaryPhotos([removed]);
  }

  Future<void> _addDriver() async {
    final input = await showDialog<DriverInput>(
      context: context,
      builder: (_) => const _DriverDialog(),
    );
    if (input != null) {
      setState(() {
        _conductores.add(input);
      });
    }
  }

  Future<void> _editDriver(int index) async {
    final input = await showDialog<DriverInput>(
      context: context,
      builder: (_) => _DriverDialog(initialValue: _conductores[index]),
    );
    if (input != null) {
      setState(() {
        _conductores[index] = input;
      });
    }
  }

  void _removeDriver(int index) {
    setState(() {
      _conductores.removeAt(index);
      for (var vehicleIndex = 0;
          vehicleIndex < _vehiculos.length;
          vehicleIndex++) {
        final driverIndex = _vehiculos[vehicleIndex].driverIndex;
        if (driverIndex == null) {
          continue;
        }
        if (driverIndex == index) {
          _vehiculos[vehicleIndex] =
              _vehiculos[vehicleIndex].copyWith(clearDriverIndex: true);
        } else if (driverIndex > index) {
          _vehiculos[vehicleIndex] =
              _vehiculos[vehicleIndex].copyWith(driverIndex: driverIndex - 1);
        }
      }
    });
  }

  Future<void> _addVehicle() async {
    final input = await showDialog<VehicleInput>(
      context: context,
      builder: (_) => _VehicleDialog(conductores: _conductores),
    );
    if (input != null) {
      setState(() {
        _vehiculos.add(input);
      });
    }
  }

  Future<void> _editVehicle(int index) async {
    final input = await showDialog<VehicleInput>(
      context: context,
      builder: (_) => _VehicleDialog(
        conductores: _conductores,
        initialValue: _vehiculos[index],
      ),
    );
    if (input != null) {
      setState(() {
        _vehiculos[index] = input;
      });
    }
  }

  Future<void> _addPerson() async {
    final input = await showDialog<PersonInput>(
      context: context,
      builder: (_) => const _PersonDialog(),
    );
    if (input != null) {
      setState(() {
        _personas.add(input);
      });
    }
  }

  Future<void> _editPerson(int index) async {
    final input = await showDialog<PersonInput>(
      context: context,
      builder: (_) => _PersonDialog(initialValue: _personas[index]),
    );
    if (input != null) {
      setState(() {
        _personas[index] = input;
      });
    }
  }
}

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.controller,
    required this.actor,
    required this.idInforme,
    required this.externalMapsService,
  });

  final ReportController controller;
  final AuthenticatedUser actor;
  final int idInforme;
  final ExternalMapsService externalMapsService;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late final Future<ReportRecord> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.controller.findReadableDetail(
      actor: widget.actor,
      idInforme: widget.idInforme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Detalle de informe',
      body: FutureBuilder<ReportRecord>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: AppLoadingState(message: 'Cargando detalle'),
            );
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'No se pudo abrir',
              message: snapshot.error.toString(),
            );
          }
          final report = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                report.numeroCaso,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text('Informe finalizado. Modo lectura.'),
              _ReadOnlySection(
                title: 'Datos generales',
                rows: {
                  'EPI': report.epi,
                  'Llegada': _formatOptionalDateTime(report.fechaHoraLlegada),
                  'Hecho': _formatOptionalDateTime(report.fechaHoraHecho),
                  'Naturaleza': report.naturaleza,
                  'Lugar': report.lugar,
                },
              ),
              _ReadOnlySection(
                title: 'Denunciante',
                rows: {
                  'Nombre': report.denuncianteNombre,
                  'Documento': report.denuncianteDocumento,
                  'Contacto': report.denuncianteContacto,
                },
              ),
              _ReadOnlySection(
                title: 'Descripcion y condiciones',
                rows: {
                  'Descripcion': report.descripcion,
                  'Condiciones climaticas': report.condicionesClimaticas,
                  'Vehiculos movidos': _boolText(report.vehiculosMovidos),
                  'Protagonistas presentes':
                      _boolText(report.protagonistasPresentes),
                  'Testigos': report.testigos,
                  'Efectos personales': report.efectosPersonales,
                },
              ),
              _ReadOnlySection(
                title: 'Coordenadas y croquis',
                rows: {
                  'Latitud': report.latitud?.toString(),
                  'Longitud': report.longitud?.toString(),
                  'Ruta de croquis': report.rutaCroquis,
                },
              ),
              if (report.latitud != null && report.longitud != null) ...[
                SimpleSketchMap(
                  latitude: report.latitud!,
                  longitude: report.longitud!,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openCoordinatesExternally(report),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir coordenadas en mapas'),
                ),
              ] else
                const _InlineNotice(
                  message:
                      'Este informe no tiene coordenadas registradas; se conserva el lugar textual.',
                ),
              _ReadOnlyList(
                title: 'Conductores',
                values: report.conductores
                    .map((driver) => '${driver.nombreCompleto} - '
                        '${driver.licencia ?? 'No aplica'}')
                    .toList(),
              ),
              _ReadOnlyList(
                title: 'Vehiculos',
                values: report.vehiculos
                    .map((vehicle) => [
                          vehicle.placa ?? 'Sin placa',
                          vehicle.marca,
                          vehicle.color,
                          vehicle.tipo,
                          vehicle.servicio,
                        ].whereType<String>().join(' / '))
                    .toList(),
              ),
              _ReadOnlyList(
                title: 'Personas involucradas',
                values: report.personas
                    .map((person) => '${person.tipo}: ${person.nombre}')
                    .toList(),
              ),
              _Section(
                title: 'Fotografias',
                children: [
                  _ReadOnlyPhotoGrid(photos: report.fotografias),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCoordinatesExternally(ReportRecord report) async {
    final opened = await widget.externalMapsService.openCoordinates(
      latitude: report.latitud!,
      longitude: report.longitud!,
    );
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se encontro una aplicacion compatible de mapas.'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _RelationSection extends StatelessWidget {
  const _RelationSection({
    required this.title,
    required this.emptyText,
    required this.count,
    required this.onAdd,
    required this.itemBuilder,
  });

  final String title;
  final String emptyText;
  final int count;
  final VoidCallback onAdd;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      children: [
        if (count == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(emptyText),
          )
        else
          ...List.generate(count, itemBuilder),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onCategoryChanged,
    required this.onRemove,
  });

  final List<PhotoInput> photos;
  final void Function(int index, EvidencePhotoCategory category)
      onCategoryChanged;
  final Future<void> Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final file = File(photo.ruta);
        final exists = file.existsSync();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: exists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PhotoProblem(
                          message: 'No se pudo mostrar la imagen.',
                        ),
                      )
                    : const _PhotoProblem(
                        message: 'Archivo inexistente.',
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: DropdownButtonFormField<EvidencePhotoCategory>(
                  initialValue: photo.tipo,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    isDense: true,
                  ),
                  items: EvidencePhotoCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (category) {
                    if (category != null) {
                      onCategoryChanged(index, category);
                    }
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Quitar fotografia',
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReadOnlyPhotoGrid extends StatelessWidget {
  const _ReadOnlyPhotoGrid({required this.photos});

  final List<PhotoRecord> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Text('No existe.');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 228,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final file = File(photo.ruta);
        final exists = file.existsSync();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: exists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PhotoProblem(
                          message: 'No se pudo mostrar la imagen.',
                        ),
                      )
                    : const _PhotoProblem(
                        message: 'Archivo inexistente.',
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${photo.tipo.label}\n${photo.ruta}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoProblem extends StatelessWidget {
  const _PhotoProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableSummary extends StatelessWidget {
  const _EditableSummary({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: IconButton(
          tooltip: 'Quitar',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

class _ReadOnlySection extends StatelessWidget {
  const _ReadOnlySection({required this.title, required this.rows});

  final String title;
  final Map<String, String?> rows;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      children: rows.entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${entry.key}: ${entry.value ?? 'No aplica'}'),
            ),
          )
          .toList(),
    );
  }
}

class _ReadOnlyList extends StatelessWidget {
  const _ReadOnlyList({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      children: values.isEmpty
          ? const [Text('No existe.')]
          : values.map((value) => Text(value)).toList(),
    );
  }
}

class _DriverDialog extends StatefulWidget {
  const _DriverDialog({this.initialValue});

  final DriverInput? initialValue;

  @override
  State<_DriverDialog> createState() => _DriverDialogState();
}

class _DriverDialogState extends State<_DriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _edad = TextEditingController();
  final _licencia = TextEditingController();
  final _categoria = TextEditingController();
  final _domicilio = TextEditingController();
  final _zona = TextEditingController();
  final _contactos = TextEditingController();
  final _condicionEntrega = TextEditingController();

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    if (value == null) {
      return;
    }
    _nombre.text = value.nombreCompleto;
    _edad.text = value.edad?.toString() ?? '';
    _licencia.text = value.licencia ?? '';
    _categoria.text = value.categoria ?? '';
    _domicilio.text = value.domicilio ?? '';
    _zona.text = value.zona ?? '';
    _contactos.text = value.contactos ?? '';
    _condicionEntrega.text = value.condicionEntrega ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _edad.dispose();
    _licencia.dispose();
    _categoria.dispose();
    _domicilio.dispose();
    _zona.dispose();
    _contactos.dispose();
    _condicionEntrega.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InputDialog(
      title: widget.initialValue == null
          ? 'Agregar conductor'
          : 'Revisar conductor',
      submitLabel: widget.initialValue == null ? 'Agregar' : 'Guardar',
      formKey: _formKey,
      children: [
        _field(_nombre, 'Nombre completo'),
        _field(
          _edad,
          'Edad',
          keyboardType: TextInputType.number,
          validator: _validateRequiredInt,
        ),
        _field(_licencia, 'Licencia'),
        _field(_categoria, 'Categoria'),
        _field(_domicilio, 'Domicilio'),
        _field(_zona, 'Zona'),
        _field(_contactos, 'Contactos'),
        _field(_condicionEntrega, 'Condicion de entrega', required: false),
      ],
      onSubmit: () {
        if (!(_formKey.currentState?.validate() ?? false)) {
          return;
        }
        Navigator.of(context).pop(
          DriverInput(
            nombreCompleto: _nombre.text.trim(),
            edad: _parseOptionalInt(_edad.text),
            licencia: _optionalText(_licencia.text),
            categoria: _optionalText(_categoria.text),
            domicilio: _optionalText(_domicilio.text),
            zona: _optionalText(_zona.text),
            contactos: _optionalText(_contactos.text),
            condicionEntrega: _optionalText(_condicionEntrega.text),
          ),
        );
      },
    );
  }
}

class _VehicleDialog extends StatefulWidget {
  const _VehicleDialog({required this.conductores, this.initialValue});

  final List<DriverInput> conductores;
  final VehicleInput? initialValue;

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _placa = TextEditingController();
  final _marca = TextEditingController();
  final _color = TextEditingController();
  final _tipo = TextEditingController();
  final _servicio = TextEditingController();
  int? _driverIndex;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    if (value == null) {
      return;
    }
    _driverIndex = value.driverIndex;
    _placa.text = value.placa ?? '';
    _marca.text = value.marca ?? '';
    _color.text = value.color ?? '';
    _tipo.text = value.tipo ?? '';
    _servicio.text = value.servicio ?? '';
  }

  @override
  void dispose() {
    _placa.dispose();
    _marca.dispose();
    _color.dispose();
    _tipo.dispose();
    _servicio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InputDialog(
      title:
          widget.initialValue == null ? 'Agregar vehiculo' : 'Revisar vehiculo',
      submitLabel: widget.initialValue == null ? 'Agregar' : 'Guardar',
      formKey: _formKey,
      children: [
        if (widget.conductores.isNotEmpty)
          DropdownButtonFormField<int?>(
            initialValue: _driverIndex,
            decoration: const InputDecoration(
              labelText: 'Conductor relacionado',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('No aplica'),
              ),
              ...List.generate(
                widget.conductores.length,
                (index) => DropdownMenuItem<int?>(
                  value: index,
                  child: Text(widget.conductores[index].nombreCompleto),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _driverIndex = value;
            }),
          ),
        if (widget.conductores.isNotEmpty) const SizedBox(height: 12),
        _field(_placa, 'Placa'),
        _field(_marca, 'Marca'),
        _field(_color, 'Color'),
        _field(_tipo, 'Tipo'),
        _field(_servicio, 'Servicio'),
      ],
      onSubmit: () {
        if (!(_formKey.currentState?.validate() ?? false)) {
          return;
        }
        Navigator.of(context).pop(
          VehicleInput(
            driverIndex: _driverIndex,
            placa: _optionalText(_placa.text),
            marca: _optionalText(_marca.text),
            color: _optionalText(_color.text),
            tipo: _optionalText(_tipo.text),
            servicio: _optionalText(_servicio.text),
          ),
        );
      },
    );
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({this.initialValue});

  final PersonInput? initialValue;

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _edad = TextEditingController();
  final _lugarEvacuacion = TextEditingController();
  String _tipo = 'HERIDO';

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    if (value == null) {
      return;
    }
    _nombre.text = value.nombre;
    _edad.text = value.edad?.toString() ?? '';
    _tipo = value.tipo;
    _lugarEvacuacion.text = value.lugarEvacuacion ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _edad.dispose();
    _lugarEvacuacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InputDialog(
      title: widget.initialValue == null
          ? 'Agregar persona involucrada'
          : 'Revisar persona involucrada',
      submitLabel: widget.initialValue == null ? 'Agregar' : 'Guardar',
      formKey: _formKey,
      children: [
        _field(_nombre, 'Nombre'),
        _field(
          _edad,
          'Edad',
          keyboardType: TextInputType.number,
          validator: _validateRequiredInt,
        ),
        DropdownButtonFormField<String>(
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: const [
            DropdownMenuItem(value: 'HERIDO', child: Text('Herido')),
            DropdownMenuItem(value: 'FALLECIDO', child: Text('Fallecido')),
          ],
          onChanged: (value) => setState(() {
            _tipo = value ?? 'HERIDO';
          }),
        ),
        const SizedBox(height: 12),
        _field(_lugarEvacuacion, 'Lugar de evacuacion', required: false),
      ],
      onSubmit: () {
        if (!(_formKey.currentState?.validate() ?? false)) {
          return;
        }
        Navigator.of(context).pop(
          PersonInput(
            nombre: _nombre.text.trim(),
            tipo: _tipo,
            edad: _parseOptionalInt(_edad.text),
            lugarEvacuacion: _optionalText(_lugarEvacuacion.text),
          ),
        );
      },
    );
  }
}

class _InputDialog extends StatelessWidget {
  const _InputDialog({
    required this.title,
    required this.submitLabel,
    required this.formKey,
    required this.children,
    required this.onSubmit,
  });

  final String title;
  final String submitLabel;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: onSubmit,
          child: Text(submitLabel),
        ),
      ],
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool required = true,
  bool readOnly = false,
  int maxLines = 1,
  String? helperText,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
      ),
      textInputAction: maxLines == 1 ? TextInputAction.next : null,
      validator: validator ??
          (value) {
            if (required && (value ?? '').trim().isEmpty) {
              return 'Campo obligatorio.';
            }
            return null;
          },
    ),
  );
}

Widget _dateField({
  required TextEditingController controller,
  required String label,
  required DateTime? value,
  required ValueChanged<DateTime> onChanged,
}) {
  return Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.event_outlined),
        ),
        validator: (_) => value == null ? 'Campo obligatorio.' : null,
        onTap: () async {
          final now = DateTime.now();
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 10),
            lastDate: DateTime(now.year + 1),
          );
          if (date == null || !context.mounted) {
            return;
          }
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? now),
          );
          if (time == null) {
            return;
          }
          onChanged(
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
          );
        },
      ),
    ),
  );
}

Widget _boolChoice({
  required String label,
  required bool? value,
  required ValueChanged<bool?> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FormField<bool>(
      initialValue: value,
      validator: (_) => value == null ? 'Campo obligatorio.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.check_rounded),
                label: Text('Si'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.close_rounded),
                label: Text('No'),
              ),
            ],
            selected: value == null ? <bool>{} : <bool>{value},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              final next = selection.isEmpty ? null : selection.first;
              field.didChange(next);
              onChanged(next);
            },
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Text(
              field.errorText!,
              style:
                  TextStyle(color: Theme.of(field.context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );
}

String? _validateOptionalDouble(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(text) == null ? 'Ingrese un numero valido.' : null;
}

String? _validateOptionalInt(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(text);
  if (parsed == null || parsed < 0) {
    return 'Ingrese un numero valido.';
  }
  return null;
}

String? _validateRequiredInt(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return 'Campo obligatorio.';
  }
  return _validateOptionalInt(value);
}

double? _parseOptionalDouble(String value) {
  final text = value.trim();
  return text.isEmpty ? null : double.parse(text);
}

double? _tryParseOptionalDouble(String value) {
  final text = value.trim();
  return text.isEmpty ? null : double.tryParse(text);
}

int? _parseOptionalInt(String value) {
  final text = value.trim();
  return text.isEmpty ? null : int.parse(text);
}

String? _optionalText(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _formatDateTime(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _formatOptionalDateTime(DateTime? value) {
  return value == null ? 'No aplica' : _formatDateTime(value);
}

String _boolText(bool? value) {
  if (value == null) {
    return 'No aplica';
  }
  return value ? 'Si' : 'No';
}
