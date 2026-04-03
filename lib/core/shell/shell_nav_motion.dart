import 'package:flutter/animation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellPageProgressProvider = StateProvider<double?>((ref) => null);

double shellSelectionWeight(double page, int index) {
  final distance = (page - index).abs().clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(1 - distance);
}

double shellTravelTension(double page) {
  final fraction = page - page.floorToDouble();
  final mirrored = fraction <= 0.5 ? fraction : 1 - fraction;
  return Curves.easeOutCubic.transform((mirrored / 0.5).clamp(0.0, 1.0));
}
