import 'package:flutter/animation.dart';

/// One place for NoteNest's motion language — soft, springy and quick.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration stagger = Duration(milliseconds: 55);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve springy = Curves.easeOutBack;
  static const Curve gentle = Curves.easeOutQuad;
}
