import 'package:flutter/material.dart';

/// Corner radius tokens based on brain/03_DESIGN_SPEC.md v1.2.
abstract final class AppRadius {
  static const double card = 12.0;
  static const double cardLarge = 16.0;
  static const double input = 12.0;
  static const double button = 12.0;
  static const double thumbnail = 8.0;
  static const double sheetTop = 24.0;
  static const double pill = 999.0;

  // BorderRadius objects
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius cardLargeRadius = BorderRadius.all(Radius.circular(cardLarge));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(input));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius thumbnailRadius = BorderRadius.all(Radius.circular(thumbnail));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheetTopRadius = BorderRadius.only(
    topLeft: Radius.circular(sheetTop),
    topRight: Radius.circular(sheetTop),
  );
}
