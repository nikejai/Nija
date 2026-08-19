import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wireframe-aligned typography for the vault dashboard / workspace shell.
class DashboardTypography {
  DashboardTypography._();

  static TextStyle microLabel(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.8,
    height: 1.2,
    color: color,
  );

  static TextStyle workspaceBrand(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.8,
    height: 1.2,
    color: color,
  );

  static TextStyle workspaceTitle(Color color) => GoogleFonts.inter(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: color,
  );

  static TextStyle greetingTitle(Color color) => GoogleFonts.inter(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.3,
    color: color,
  );

  static TextStyle greetingSubtitle(Color color) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle panelTitle(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle statValue(Color color) => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: color,
  );

  static TextStyle statLabel(Color color) => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: color,
  );

  static TextStyle quickActionLabel(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: color,
  );

  static TextStyle navCode(Color color, {required bool selected}) =>
      GoogleFonts.robotoMono(
        fontSize: 9,
        fontWeight: FontWeight.w400,
        height: 1.0,
        color: color,
      );

  static TextStyle navLabel(Color color, {required bool selected}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        height: 1.2,
        color: color,
      );

  static TextStyle sidebarVaultName(Color color) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: color,
  );

  static TextStyle sidebarVaultMeta(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle recentTitle(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: color,
  );

  static TextStyle recentSubtitle(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle recentTimestamp(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: color,
  );

  static TextStyle typeCode(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: color,
  );

  static TextStyle textLink(Color color) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: color,
  );
}
