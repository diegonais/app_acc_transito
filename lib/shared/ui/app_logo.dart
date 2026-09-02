import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo institucional de Transito',
      image: true,
      child: Image.asset(
        AppConstants.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
