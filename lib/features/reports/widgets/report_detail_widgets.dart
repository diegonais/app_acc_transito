import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/qr/institutional_qr_service.dart';
import '../../../shared/report_format.dart';

class ReportDetailSection extends StatelessWidget {
  const ReportDetailSection(
      {super.key,
      required this.title,
      required this.icon,
      required this.child,
      this.count});
  final String title;
  final IconData icon;
  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          if (count != null)
            Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('$count', style: theme.textTheme.titleMedium)),
        ]),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class InformationFields extends StatelessWidget {
  const InformationFields({super.key, required this.fields});
  final Map<String, String?> fields;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 500 &&
                MediaQuery.textScalerOf(context).scale(14) < 23
            ? 2
            : 1;
        return Wrap(spacing: 24, runSpacing: 16, children: [
          for (final field in fields.entries)
            SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 24) / columns,
                child: InformationRow(label: field.key, value: field.value)),
        ]);
      });
}

class InformationRow extends StatelessWidget {
  const InformationRow({super.key, required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(ReportFormat.value(value),
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4)),
      ]);
}

class StatusRow extends StatelessWidget {
  const StatusRow({super.key, required this.label, required this.value});
  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              Chip(
                  label: Text(ReportFormat.boolean(value)),
                  visualDensity: VisualDensity.compact),
            ]),
      );
}

class EmptySectionMessage extends StatelessWidget {
  const EmptySectionMessage(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8)),
        child: Text(message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4)),
      );
}

class ReportRecordCard extends StatelessWidget {
  const ReportRecordCard(
      {super.key,
      required this.label,
      required this.title,
      required this.fields});
  final String label;
  final String title;
  final Map<String, String?> fields;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
            elevation: 0,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 4),
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      InformationFields(fields: fields),
                    ]))),
      );
}

class ReportImageCard extends StatelessWidget {
  const ReportImageCard(
      {super.key,
      required this.path,
      required this.title,
      this.description,
      this.isSketch = false});
  final String path;
  final String title;
  final String? description;
  final bool isSketch;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ReportImageViewer(path: path, title: title))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: isSketch ? 4 / 3 : 3 / 2,
              child: Image.file(File(path),
                  fit: BoxFit.contain,
                  cacheWidth: isSketch ? 1200 : 600,
                  semanticLabel: title,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.broken_image_outlined, size: 32),
                            SizedBox(height: 8),
                            Text('Imagen no disponible',
                                textAlign: TextAlign.center),
                          ])))),
            ),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      if (description != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(description!)),
                      const SizedBox(height: 6),
                      Text('Tocar para ampliar',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                    ])),
          ]),
        ),
      );
}

class ReportImageViewer extends StatelessWidget {
  const ReportImageViewer({super.key, required this.path, required this.title});
  final String path;
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
            child: SizedBox.expand(
                child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
              child: Image.file(File(path),
                  fit: BoxFit.contain,
                  semanticLabel: title,
                  errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptySectionMessage(
                          'La imagen no está disponible en este dispositivo.')))),
        ))),
      );
}

class InstitutionalQrView extends StatelessWidget {
  const InstitutionalQrView({super.key, required this.code});
  final InstitutionalQrCode code;
  @override
  Widget build(BuildContext context) => Semantics(
        label:
            'QR institucional del funcionario ${code.payload.nombreCompleto}',
        image: true,
        child: SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(painter: _QrPainter(code))),
      );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.code);
  final InstitutionalQrCode code;
  @override
  void paint(Canvas canvas, Size size) {
    // Negro sobre blanco y cuatro módulos libres para permitir el escaneo.
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final unit = size.shortestSide / (code.moduleCount + 8);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < code.moduleCount; row++) {
      for (var col = 0; col < code.moduleCount; col++) {
        if (code.image.isDark(row, col))
          canvas.drawRect(
              Rect.fromLTWH((col + 4) * unit, (row + 4) * unit, unit, unit),
              paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.code != code;
}
