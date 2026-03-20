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
      'doc' || 'docx' => const Color(0xFF1565C0),
      'xls' || 'xlsx' => const Color(0xFF2E7D32),
      'ppt' || 'pptx' => const Color(0xFFE65100),
      'zip' || 'rar' || '7z' => const Color(0xFF6A1B9A),
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => const Color(0xFF00838F),
      'mp4' || 'mov' || 'avi' => const Color(0xFFAD1457),
      'txt' || 'md' => const Color(0xFF546E7A),
      _ => const Color(0xFF757575),
    };
  }

  /// Icon associated with a file extension.
  static IconData icon(String ext) {
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'xls' || 'xlsx' => Icons.table_chart_rounded,
      'ppt' || 'pptx' => Icons.slideshow_rounded,
      'zip' || 'rar' || '7z' => Icons.folder_zip_rounded,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => Icons.image_rounded,
      'mp4' || 'mov' || 'avi' => Icons.videocam_rounded,
      'txt' || 'md' => Icons.text_snippet_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }
}
