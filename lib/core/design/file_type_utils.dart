/// File type utilities — maps file extensions to icons and colors.
///
/// Usage:
///   final ext = FileTypeUtils.extractExt('report.pdf', '');
///   final icon = FileTypeUtils.icon(ext);
///   final color = FileTypeUtils.color(ext);
///
/// Centralized here to avoid duplication across file_card, unread_files_screen,
/// file_detail_screen, etc.
library;

import 'package:flutter/material.dart';

abstract final class FileTypeUtils {
  /// Extract file extension from title or explicit fileType field.
  static String extractExt(String title, String fileType) {
    if (fileType.isNotEmpty) return fileType.toLowerCase();
    final dot = title.lastIndexOf('.');
    if (dot != -1 && dot < title.length - 1) {
      return title.substring(dot + 1).toLowerCase();
    }
    return '';
  }

  /// Color associated with a file extension.
  static Color color(String ext) {
    return switch (ext) {
      'pdf' => const Color(0xFFE53935),
      'doc' || 'docx' => const Color(0xFF1976D2),
      'ppt' || 'pptx' => const Color(0xFFE65100),
      'xls' || 'xlsx' => const Color(0xFF2E7D32),
      'zip' || 'rar' || '7z' => const Color(0xFF757575),
      'png' ||
      'jpg' ||
      'jpeg' ||
      'gif' ||
      'svg' ||
      'bmp' ||
      'webp' => const Color(0xFF7B1FA2),
      'mp4' || 'mov' || 'avi' => const Color(0xFFD81B60),
      'txt' || 'md' || 'csv' || 'log' => const Color(0xFF546E7A),
      'py' ||
      'java' ||
      'c' ||
      'cpp' ||
      'js' ||
      'dart' ||
      'html' ||
      'css' => const Color(0xFF00897B),
      _ => const Color(0xFF546E7A),
    };
  }

  /// Icon associated with a file extension.
  static IconData icon(String ext) {
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'ppt' || 'pptx' => Icons.slideshow_rounded,
      'xls' || 'xlsx' => Icons.table_chart_rounded,
      'zip' || 'rar' || '7z' => Icons.folder_zip_rounded,
      'png' ||
      'jpg' ||
      'jpeg' ||
      'gif' ||
      'svg' ||
      'bmp' ||
      'webp' => Icons.image_rounded,
      'mp4' || 'mov' || 'avi' => Icons.videocam_rounded,
      'txt' || 'md' || 'csv' || 'log' => Icons.text_snippet_rounded,
      'py' ||
      'java' ||
      'c' ||
      'cpp' ||
      'js' ||
      'dart' ||
      'html' ||
      'css' => Icons.code_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }
}
