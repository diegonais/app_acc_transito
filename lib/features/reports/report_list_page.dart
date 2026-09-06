import 'dart:io';

import 'package:flutter/material.dart';
import '../../shared/user_message.dart';
import 'package:flutter/rendering.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
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
import 'report_detail_page.dart';

export 'report_detail_page.dart' show ReportDetailPage;

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
  int? _selectedPoliceId;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).currentUser;
      if (user != null) {
        widget.controller.load(user, filter: _currentFilter);
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
          onPressed: () => widget.controller.load(user, filter: _currentFilter),
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
              onRetry: () => controller.load(user, filter: _currentFilter),
            );
          }
          if (controller.reports.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ReportHeader(
                  user: user,
                  onCreate: () => _openForm(user),
                ),
                const SizedBox(height: 12),
                _ReportFilters(
                  isAdmin: user.isAdmin,
                  policeOptions: controller.policeOptions,
                  selectedPoliceId: _selectedPoliceId,
                  from: _from,
                  to: _to,
                  onPoliceChanged: (value) async {
                    setState(() => _selectedPoliceId = value);
                    await widget.controller.load(user, filter: _currentFilter);
                  },
                  onPickFrom: () => _pickFilterDate(user, isFrom: true),
                  onPickTo: () => _pickFilterDate(user, isFrom: false),
                  onClear: () => _clearFilters(user),
                ),
                const SizedBox(height: 32),
                _EmptyReports(
                  hasFilters: !_currentFilter.isEmpty,
                  isPolice: user.isPolice,
                  onCreate: () => _openForm(user),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.reports.length + 2,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ReportHeader(
                  user: user,
                  onCreate: () => _openForm(user),
                );
              }
              if (index == 1) {
                return _ReportFilters(
                  isAdmin: user.isAdmin,
                  policeOptions: controller.policeOptions,
                  selectedPoliceId: _selectedPoliceId,
                  from: _from,
                  to: _to,
                  onPoliceChanged: (value) async {
                    setState(() => _selectedPoliceId = value);
                    await widget.controller.load(user, filter: _currentFilter);
                  },
                  onPickFrom: () => _pickFilterDate(user, isFrom: true),
                  onPickTo: () => _pickFilterDate(user, isFrom: false),
                  onClear: () => _clearFilters(user),
                );
              }
              final report = controller.reports[index - 2];
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
      await widget.controller.load(user, filter: _currentFilter);
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
          'El informe ${report.numeroCaso} dejará de mostrarse en la '
          'aplicación. No se borrará su contenido ni sus relaciones.',
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
    if (confirmed != true || !mounted) {
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
        SnackBar(
            content: Text(userMessage(error,
                fallback: 'No se pudo inactivar el informe.'))),
      );
    }
  }

  ReportQueryFilter get _currentFilter {
    return ReportQueryFilter(
      idPolicia: _selectedPoliceId,
      from: _from == null
          ? null
          : DateTime(_from!.year, _from!.month, _from!.day),
      to: _to == null
          ? null
          : DateTime(_to!.year, _to!.month, _to!.day).add(
              const Duration(days: 1),
            ),
    );
  }

  Future<void> _pickFilterDate(
    AuthenticatedUser user, {
    required bool isFrom,
  }) async {
    final current = isFrom ? _from : _to;
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
    await widget.controller.load(user, filter: _currentFilter);
  }

  Future<void> _clearFilters(AuthenticatedUser user) async {
    setState(() {
      _selectedPoliceId = null;
      _from = null;
      _to = null;
    });
    await widget.controller.load(user, filter: _currentFilter);
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
  const _EmptyReports({
    required this.hasFilters,
    required this.isPolice,
    required this.onCreate,
  });

  final bool hasFilters;
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
              title: 'Sin resultados',
              message: 'No existen informes activos con estos criterios.',
              icon: Icons.assignment_outlined,
            ),
            if (isPolice && !hasFilters) ...[
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

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.isAdmin,
    required this.policeOptions,
    required this.selectedPoliceId,
    required this.from,
    required this.to,
    required this.onPoliceChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClear,
  });

  final bool isAdmin;
  final List<PoliceReportCount> policeOptions;
  final int? selectedPoliceId;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<int?> onPoliceChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros de consulta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (isAdmin) ...[
              DropdownButtonFormField<int?>(
                initialValue: selectedPoliceId,
                decoration: const InputDecoration(
                  labelText: 'Policía',
                  prefixIcon: Icon(Icons.local_police_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ...policeOptions.map(
                    (police) => DropdownMenuItem<int?>(
                      value: police.idPolicia,
                      child: Text(
                        police.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onPoliceChanged,
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickFrom,
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Desde ${_formatOptionalDate(from)}'),
                ),
                OutlinedButton.icon(
                  onPressed: onPickTo,
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text('Hasta ${_formatOptionalDate(to)}'),
                ),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
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
  static const _totalSteps = 6;
  final _stepFormKeys =
      List.generate(_totalSteps, (_) => GlobalKey<FormState>());
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
  int _currentStep = 0;
  String? _errorMessage;
  String? _geoMessage;
  String? _mapMessage;
  String? _photoMessage;
  bool _allowExit = false;
  bool _isCanceling = false;
  final _generatedSketches = <String>{};
  bool get _isBusy =>
      _isSubmitting || _isLocating || _isCapturingSketch || _isPickingPhoto;

  @override
  void initState() {
    super.initState();
    _latitud.addListener(_coordinatesChanged);
    _longitud.addListener(_coordinatesChanged);
  }

  void _coordinatesChanged() {
    if (!mounted) return;
    setState(() => _rutaCroquis.clear());
  }

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
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _cancel();
      },
      child: AppScaffoldShell(
        title: 'Informe de Acción Directa',
        body: Column(
          children: [
            _WizardProgress(
              currentStep: _currentStep + 1,
              totalSteps: _totalSteps,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Form(
                    key: _stepFormKeys[_currentStep],
                    child: AbsorbPointer(
                        absorbing: _isBusy, child: _stepCard(_currentStep)),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _WizardNavigation(
                    isFirstStep: _currentStep == 0,
                    isLastStep: _currentStep == _totalSteps - 1,
                    isBusy: _isBusy,
                    onPrevious: _previousStep,
                    onNext: _nextStep,
                    onFinalize: _finalize,
                    onCancel: _cancel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(int step) {
    final content = switch (step) {
      0 => _generalDataStep(),
      1 => _complainantStep(),
      2 => _descriptionConditionsStep(),
      3 => _coordinatesStep(),
      4 => _photosDriversStep(),
      _ => _vehiclesPeopleStep(),
    };

    return _WizardStepCard(
      icon: _stepIcon(step),
      title: _stepTitle(step),
      description: _stepDescription(step),
      child: content,
    );
  }

  Widget _generalDataStep() {
    return Column(
      children: [
        _field(_epi, 'EPI / Estación Policial Integral'),
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
    );
  }

  Widget _complainantStep() {
    return Column(
      children: [
        _field(_denuncianteNombre, 'Denunciante'),
        _field(
          _denuncianteDocumento,
          'Documento del denunciante',
          required: false,
        ),
        _field(_denuncianteContacto, 'Contacto del denunciante'),
      ],
    );
  }

  Widget _descriptionConditionsStep() {
    return Column(
      children: [
        _field(_descripcion, 'Descripción', maxLines: 5),
        _field(_condicionesClimaticas, 'Condiciones climáticas'),
        _boolChoice(
          label: 'Vehículos movidos',
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
    );
  }

  Widget _coordinatesStep() {
    return Column(
      children: [
        _FullWidthOutlinedButton(
          onPressed: _isLocating ? null : _locateIncident,
          icon: _isLocating ? null : Icons.location_on_outlined,
          label: _isLocating ? 'Obteniendo ubicación' : 'Obtener ubicación',
          isBusy: _isLocating,
        ),
        const SizedBox(height: 10),
        _FullWidthOutlinedButton(
          onPressed: _hasCoordinates
              ? () => _openCoordinatesExternally(
                    _currentLatitude!,
                    _currentLongitude!,
                  )
              : null,
          icon: Icons.map_outlined,
          label: 'Abrir en mapas',
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
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          validator: (_) => _coordinateError(isLatitude: true),
        ),
        _field(
          _longitud,
          'Longitud',
          required: false,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          validator: (_) => _coordinateError(isLatitude: false),
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
                        ? 'La cartografía no cargó correctamente. Las coordenadas se conservan y el informe puede finalizarse.'
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
          _FullWidthOutlinedButton(
            onPressed: _isCapturingSketch ? null : _captureSketchMap,
            icon: _isCapturingSketch ? null : Icons.image_outlined,
            label: _isCapturingSketch
                ? 'Preparando croquis'
                : 'Preparar PNG para PDF',
            isBusy: _isCapturingSketch,
          ),
        ] else
          const _InlineNotice(
            message:
                'Sin coordenadas registradas. Puede finalizar el informe conservando el lugar textual.',
          ),
      ],
    );
  }

  Widget _photosDriversStep() {
    return Column(
      children: [
        _FullWidthOutlinedButton(
          onPressed: _isPickingPhoto ? null : () => _addPhotoFromCamera(),
          icon: _isPickingPhoto ? null : Icons.photo_camera_outlined,
          label: 'Cámara',
          isBusy: _isPickingPhoto,
        ),
        const SizedBox(height: 10),
        _FullWidthOutlinedButton(
          onPressed: _isPickingPhoto ? null : () => _addPhotosFromGallery(),
          icon: Icons.photo_library_outlined,
          label: 'Galería',
        ),
        if (_photoMessage != null) ...[
          const SizedBox(height: 8),
          _InlineNotice(message: _photoMessage!),
        ],
        const SizedBox(height: 12),
        if (_fotografias.isEmpty)
          const _EmptyStepText('No existen fotografías agregadas.')
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
        const SizedBox(height: 22),
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
                'Categoría: ${driver.categoria}',
                'Contactos: ${driver.contactos}',
              ].join(' / '),
              onTap: () => _editDriver(index),
              onDelete: () => _removeDriver(index),
            );
          },
        ),
      ],
    );
  }

  Widget _vehiclesPeopleStep() {
    return Column(
      children: [
        _RelationSection(
          title: 'Vehículos',
          emptyText: 'No existen vehículos registrados.',
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
        const SizedBox(height: 16),
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
      ],
    );
  }

  IconData _stepIcon(int step) {
    return switch (step) {
      0 => Icons.description_outlined,
      1 => Icons.person_outline_rounded,
      2 => Icons.article_outlined,
      3 => Icons.location_on_outlined,
      4 => Icons.photo_camera_outlined,
      _ => Icons.checklist_rounded,
    };
  }

  String _stepTitle(int step) {
    return switch (step) {
      0 => 'Datos generales',
      1 => 'Denunciante',
      2 => 'Descripción y condiciones',
      3 => 'Coordenadas y croquis',
      4 => 'Fotografías y archivos',
      _ => 'Vehículos y personas involucradas',
    };
  }

  String _stepDescription(int step) {
    return switch (step) {
      0 => 'Registre la información básica del hecho.',
      1 => 'Identifique a la persona denunciante.',
      2 => 'Detalle lo sucedido y las condiciones observadas.',
      3 => 'Registre la ubicación y la referencia del lugar.',
      4 => 'Adjunte evidencia y registre conductores.',
      _ => 'Complete los registros finales antes de cerrar el informe.',
    };
  }

  Future<void> _nextStep() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    if (!(_stepFormKeys[_currentStep].currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      if (_currentStep == 3 && _hasCoordinates && _rutaCroquis.text.isEmpty) {
        await _captureSketchMap(showSuccessMessage: false);
        if (!mounted) return;
      }
      setState(() {
        _currentStep += 1;
        _errorMessage = null;
      });
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
        _errorMessage = null;
      });
    }
  }

  bool _validateBeforeFinalize() {
    final invalidStep = _firstInvalidStep();
    if (invalidStep == null) {
      return true;
    }
    setState(() {
      _currentStep = invalidStep;
      _errorMessage = 'Revise los campos obligatorios de este paso.';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _stepFormKeys[invalidStep].currentState?.validate();
      }
    });
    return false;
  }

  int? _firstInvalidStep() {
    if (_isBlank(_epi.text) ||
        _fechaHoraLlegada == null ||
        _fechaHoraHecho == null ||
        _isBlank(_naturaleza.text) ||
        _isBlank(_lugar.text)) {
      return 0;
    }
    if (_isBlank(_denuncianteNombre.text) ||
        _isBlank(_denuncianteContacto.text)) {
      return 1;
    }
    if (_isBlank(_descripcion.text) ||
        _isBlank(_condicionesClimaticas.text) ||
        _vehiculosMovidos == null ||
        _protagonistasPresentes == null ||
        _isBlank(_testigos.text) ||
        _isBlank(_efectosPersonales.text)) {
      return 2;
    }
    if (_coordinateError(isLatitude: true) != null ||
        _coordinateError(isLatitude: false) != null) {
      return 3;
    }
    return null;
  }

  bool _isBlank(String value) => value.trim().isEmpty;

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
      _currentLatitude != null &&
      _currentLongitude != null &&
      _coordinateError(isLatitude: true) == null &&
      _coordinateError(isLatitude: false) == null;

  String? _coordinateError({required bool isLatitude}) {
    final text = (isLatitude ? _latitud : _longitud).text.trim();
    final other = (isLatitude ? _longitud : _latitud).text.trim();
    if (text.isEmpty) {
      return other.isEmpty
          ? null
          : 'Ingrese ambas coordenadas o deje ambas vacías.';
    }
    final value = double.tryParse(text);
    final limit = isLatitude ? 90 : 180;
    if (value == null || !value.isFinite || value.abs() > limit) {
      return 'Ingrese un valor entre -$limit y $limit.';
    }
    return null;
  }

  double? get _currentLatitude => _tryParseOptionalDouble(_latitud.text);

  double? get _currentLongitude => _tryParseOptionalDouble(_longitud.text);

  Future<void> _finalize() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    if (!_validateBeforeFinalize()) {
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
      if (!mounted) return;
      final submittedPhotos = List<PhotoInput>.of(_fotografias);
      final finalized = await widget.controller.finalize(
        actor: widget.actor,
        draft: _draft,
        persistPhotosForCase:
            widget.evidenceMediaService.persistPhotosForReport,
        cleanupPersistedPhotos:
            widget.evidenceMediaService.cleanupPersistentPhotos,
      );
      try {
        await widget.evidenceMediaService
            .cleanupTemporaryPhotos(submittedPhotos);
        await widget.mapSnapshotService.cleanupGeneratedSketches(
          _generatedSketches
              .where((path) => path != _rutaCroquis.text)
              .toList(),
        );
      } catch (error) {
        userMessage(error,
            fallback:
                'El informe se guardó, pero no se pudieron limpiar las copias temporales.');
      }
      if (mounted) {
        setState(() => _allowExit = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.of(context).pop(finalized);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = userMessage(error,
              fallback:
                  'No se pudo guardar el informe. Los datos se conservan para reintentar.');
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
        if (path != null)
          await widget.mapSnapshotService.cleanupGeneratedSketches([path]);
        return;
      }
      setState(() {
        if (path == null) {
          _mapMessage =
              'No se pudo preparar el PNG del croquis. El informe puede finalizarse conservando las coordenadas.';
        } else {
          _generatedSketches.add(path);
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
        _mapMessage = userMessage(error,
            fallback:
                'No se pudo preparar el croquis. El informe puede finalizarse conservando las coordenadas.');
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
        content: Text('No se encontró una aplicación compatible de mapas.'),
      ),
    );
  }

  Future<void> _cancel() async {
    if (_isBusy || _isCanceling) return;
    _isCanceling = true;
    try {
      if (!_draft.hasData) {
        await _exitForm();
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar informe'),
          content: const Text(
            'La información ingresada no está guardada y se perderá.',
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
        await widget.mapSnapshotService
            .cleanupGeneratedSketches(_generatedSketches);
        if (!mounted) return;
        _clearDraft();
        await _exitForm();
      }
    } catch (error) {
      if (mounted)
        setState(() => _errorMessage = userMessage(error,
            fallback:
                'No se pudo descartar el informe. Inténtelo nuevamente.'));
    } finally {
      _isCanceling = false;
    }
  }

  Future<void> _exitForm() async {
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
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
        await widget.evidenceMediaService.cleanupTemporaryPhotos(photos);
        return;
      }
      setState(() {
        _fotografias.addAll(photos);
        _photoMessage = photos.isEmpty
            ? 'No se seleccionaron fotografías.'
            : 'Fotografías agregadas al formulario. Se guardarán definitivamente al finalizar.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _photoMessage = userMessage(error,
            fallback:
                'No se pudo acceder a la cámara o galería. Revise los permisos del dispositivo.');
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
      _photoMessage = 'Fotografía quitada del formulario.';
    });
    try {
      await widget.evidenceMediaService.cleanupTemporaryPhotos([removed]);
    } catch (error) {
      userMessage(error,
          fallback: 'No se pudo limpiar la copia temporal de la fotografía.');
    }
  }

  Future<void> _addDriver() async {
    final input = await showDialog<DriverInput>(
      context: context,
      builder: (_) => const _DriverDialog(),
    );
    if (input != null && mounted) {
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
    if (input != null && mounted) {
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
    if (input != null && mounted) {
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
    if (input != null && mounted) {
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
    if (input != null && mounted) {
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
    if (input != null && mounted) {
      setState(() {
        _personas[index] = input;
      });
    }
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;
    final percent = (progress * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.ink.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Paso $currentStep de $totalSteps',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  backgroundColor: AppColors.ink.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardStepCard extends StatelessWidget {
  const _WizardStepCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryGreen.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: colorScheme.primary, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _WizardNavigation extends StatelessWidget {
  const _WizardNavigation({
    required this.isFirstStep,
    required this.isLastStep,
    required this.isBusy,
    required this.onPrevious,
    required this.onNext,
    required this.onFinalize,
    required this.onCancel,
  });

  final bool isFirstStep;
  final bool isLastStep;
  final bool isBusy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinalize;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Anterior',
                icon: Icons.chevron_left_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: isFirstStep || isBusy ? null : onPrevious,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: isLastStep
                    ? (isBusy ? 'Finalizando' : 'Finalizar informe')
                    : 'Siguiente',
                icon: isLastStep
                    ? Icons.check_circle_outline_rounded
                    : Icons.chevron_right_rounded,
                onPressed: isBusy ? null : (isLastStep ? onFinalize : onNext),
              ),
            ),
          ],
        ),
        if (isLastStep) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Cancelar',
            icon: Icons.close_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: isBusy ? null : onCancel,
          ),
        ],
      ],
    );
  }
}

class _FullWidthOutlinedButton extends StatelessWidget {
  const _FullWidthOutlinedButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.isBusy = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _EmptyStepText extends StatelessWidget {
  const _EmptyStepText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
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
          key: ValueKey(photo.ruta),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: exists
                    ? Image.file(
                        file,
                        cacheWidth: 520,
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
                    labelText: 'Categoría',
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
                  tooltip: 'Quitar fotografía',
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
        _field(_categoria, 'Categoría'),
        _field(_domicilio, 'Domicilio'),
        _field(_zona, 'Zona'),
        _field(_contactos, 'Contactos'),
        _field(_condicionEntrega, 'Condición de entrega', required: false),
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
          widget.initialValue == null ? 'Agregar vehículo' : 'Revisar vehículo',
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
        _field(_lugarEvacuacion, 'Lugar de evacuación', required: false),
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
          if (time == null || !context.mounted) {
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
                label: Text('Sí'),
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

String? _validateOptionalInt(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(text);
  if (parsed == null || parsed < 0) {
    return 'Ingrese un número válido.';
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
  return text.isEmpty ? null : double.tryParse(text);
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

String _formatOptionalDate(DateTime? value) {
  if (value == null) return 'sin definir';
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}
