import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wireframe-aligned typography for the vault entry / welcome surface.
class EntryTypography {
  EntryTypography._();

  static TextStyle brandName(Color color) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle brandNameDevanagari(Color color) =>
      GoogleFonts.notoSansDevanagari(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: color,
      );

  static TextStyle brandNativeName(Color color) =>
      GoogleFonts.notoSansDevanagari(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: color,
      );

  static TextStyle brandTagline(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: color,
  );

  static TextStyle heroTitle(Color color) => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.53,
    height: 1.05,
    color: color,
  );

  static TextStyle heroDescription(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color,
  );

  static TextStyle actionCode(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: color,
  );

  static TextStyle actionTitle(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: color,
  );

  static TextStyle actionSubtitle(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle sectionLabel(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.8,
    height: 1.2,
    color: color,
  );

  static TextStyle restoreButton(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle headerTitle(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle pageHeading(Color color) => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.05,
    color: color,
  );

  static TextStyle pageDescription(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle vaultCardTitle(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: color,
  );

  static TextStyle vaultCardMeta(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle emptyStateTitle(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle emptyStateBody(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: color,
  );

  static TextStyle unlockTitle(Color color) => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.05,
    color: color,
  );

  static TextStyle unlockSubtitle(Color color) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle fieldLabel(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.6,
    height: 1.2,
    color: color,
  );

  static TextStyle unlockFooter(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle productEyebrow(Color color) => GoogleFonts.robotoMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.2,
    height: 1.2,
    color: color,
  );

  static TextStyle productTitle(Color color) => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.53,
    height: 1.05,
    color: color,
  );

  static TextStyle productDescription(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color,
  );

  static TextStyle productTag(Color color) => GoogleFonts.robotoMono(
    fontSize: 9,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.6,
    height: 1.2,
    color: color,
  );

  static TextStyle productTypeCode(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle productTypeTitle(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: color,
  );

  static TextStyle productTypeHint(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color,
  );

  static TextStyle productSectionTitle(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: color,
  );

  static TextStyle productFlowTitle(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: color,
  );

  static TextStyle productFlowHint(Color color) => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: color,
  );
}
