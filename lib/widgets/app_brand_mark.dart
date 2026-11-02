import 'package:flutter/material.dart';

import '../app_brand.dart';

/// A transparent brand mark, without a tile, enclosing ring or clipping mask.
/// Adjacent brand text supplies its accessible name, so avoid duplicate speech.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({this.width = 48, this.height = 40, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        AppBrand.markAsset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      );
}
