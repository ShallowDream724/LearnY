import 'dart:convert';

import '../api/models.dart' as api;
import '../database/database.dart' as db;

class FileWithCourse {
  const FileWithCourse({required this.file, required this.courseName});

  final db.CourseFile file;
  final String courseName;
}

FileAttachmentKind fileAttachmentKindFromName(String? rawKind) {
  if (rawKind == null || rawKind.isEmpty) {
    return FileAttachmentKind.generic;
  }
  for (final kind in FileAttachmentKind.values) {
    if (kind.name == rawKind) {
      return kind;
    }
  }
  return FileAttachmentKind.generic;
}

enum FileAttachmentKind {
  generic,
  notification,
  homeworkAttachment,
  homeworkSubmitted,
  homeworkAnswer,
  homeworkGrade,
}

class FileAttachment {
  const FileAttachment({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.previewUrl,
    required this.size,
    this.kind = FileAttachmentKind.generic,
  });

  final String id;
  final String name;
  final String downloadUrl;
  final String previewUrl;
  final String size;
  final FileAttachmentKind kind;

  String cacheKeyForCourse(String courseId) => '${kind.name}:$courseId:$id';

  String get fileType {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex >= name.length - 1) {
      return '';
    }
    return name.substring(dotIndex + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'downloadUrl': downloadUrl,
      'previewUrl': previewUrl,
      'size': size,
      'kind': kind.name,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory FileAttachment.fromApi(
    api.RemoteFile file, {
    FileAttachmentKind kind = FileAttachmentKind.generic,
  }) {
    return FileAttachment(
      id: file.id,
      name: file.name,
      downloadUrl: file.downloadUrl,
      previewUrl: file.previewUrl,
      size: file.size,
      kind: kind,
    );
  }

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      previewUrl: (json['previewUrl'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      kind: fileAttachmentKindFromName(json['kind']?.toString()),
    );
  }

  static FileAttachment? tryParseJsonString(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return FileAttachment.fromJson(decoded);
      }
      if (decoded is Map) {
        return FileAttachment.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}

    return null;
  }
}

class FileAttachmentEntry {
  const FileAttachmentEntry._({
    required this.label,
    required this.courseId,
    required this.courseName,
    this.attachment,
  });

  factory FileAttachmentEntry.fromJson({
    required String label,
    required String? rawJson,
    required String courseId,
    required String courseName,
  }) {
    return FileAttachmentEntry._(
      label: label,
      courseId: courseId,
      courseName: courseName,
      attachment: FileAttachment.tryParseJsonString(rawJson),
    );
  }

  final String label;
  final String courseId;
  final String courseName;
  final FileAttachment? attachment;

  bool get isAvailable => attachment != null;

  String get title {
    if (attachment == null || attachment!.name.isEmpty) {
      return label;
    }
    return attachment!.name;
  }

  String get size => attachment?.size ?? '';

  String? get cacheKey {
    final file = attachment;
    if (file == null) {
      return null;
    }
    return file.cacheKeyForCourse(courseId);
  }

  FileDetailRouteData? get routeData {
    final file = attachment;
    if (file == null) {
      return null;
    }
    return FileDetailRouteData.attachment(
      attachment: file,
      courseId: courseId,
      courseName: courseName,
    );
  }
}

class FileDetailRouteData {
  const FileDetailRouteData._({
    required this.courseId,
    required this.courseName,
    this.fileId,
    this.attachment,
  });

  factory FileDetailRouteData.courseFile({
    required String fileId,
    required String courseId,
    required String courseName,
  }) {
    return FileDetailRouteData._(
      fileId: fileId,
      courseId: courseId,
      courseName: courseName,
    );
  }

  factory FileDetailRouteData.attachment({
    required FileAttachment attachment,
    required String courseId,
    required String courseName,
  }) {
    return FileDetailRouteData._(
      courseId: courseId,
      courseName: courseName,
      attachment: attachment,
    );
  }

  final String? fileId;
  final String courseId;
  final String courseName;
  final FileAttachment? attachment;

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'courseId': courseId,
      'courseName': courseName,
      'attachment': attachment?.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  bool get isCourseFile => fileId != null && fileId!.isNotEmpty;

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'courseId': courseId,
      'courseName': courseName,
    };
    if (fileId != null && fileId!.isNotEmpty) {
      params['id'] = fileId!;
    }
    if (attachment != null) {
      params['attachment'] = base64Url.encode(
        utf8.encode(attachment!.toJsonString()),
      );
    }
    return params;
  }

  static FileDetailRouteData fromQueryParameters(Map<String, String> query) {
    final courseId = query['courseId'] ?? '';
    final courseName = query['courseName'] ?? '';
    final attachmentToken = query['attachment'];
    if (attachmentToken != null && attachmentToken.isNotEmpty) {
      try {
        final jsonString = utf8.decode(base64Url.decode(attachmentToken));
        final attachment = FileAttachment.tryParseJsonString(jsonString);
        if (attachment != null) {
          return FileDetailRouteData.attachment(
            attachment: attachment,
            courseId: courseId,
            courseName: courseName,
          );
        }
      } catch (_) {}
    }

    return FileDetailRouteData.courseFile(
      fileId: query['id'] ?? '',
      courseId: courseId,
      courseName: courseName,
    );
  }

  factory FileDetailRouteData.fromJson(Map<String, dynamic> json) {
    final rawAttachment = json['attachment'];
    final attachment = rawAttachment is Map<String, dynamic>
        ? FileAttachment.fromJson(rawAttachment)
        : rawAttachment is Map
        ? FileAttachment.fromJson(
            rawAttachment.map((key, value) => MapEntry(key.toString(), value)),
          )
        : null;
    return FileDetailRouteData._(
      fileId: json['fileId']?.toString(),
      courseId: (json['courseId'] ?? '').toString(),
      courseName: (json['courseName'] ?? '').toString(),
      attachment: attachment,
    );
  }

  static FileDetailRouteData? tryParseJsonString(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return FileDetailRouteData.fromJson(decoded);
      }
      if (decoded is Map) {
        return FileDetailRouteData.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}

    return null;
  }
}

class FileDetailItem {
  const FileDetailItem({
    required this.cacheKey,
    required this.sourceKind,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.description,
    required this.rawSize,
    required this.size,
    required this.uploadTime,
    required this.fileType,
    required this.downloadUrl,
    required this.previewUrl,
    required this.markedImportant,
    required this.isNew,
    required this.supportsReadState,
    this.persistedFileId,
    this.localDownloadState = 'none',
    this.localFilePath,
  });

  factory FileDetailItem.fromCourseFile(
    db.CourseFile file, {
    required String courseName,
  }) {
    return FileDetailItem(
      cacheKey: file.id,
      sourceKind: 'courseFile',
      persistedFileId: file.id,
      courseId: file.courseId,
      courseName: courseName,
      title: file.title,
      description: file.description,
      rawSize: file.rawSize,
      size: file.size,
      uploadTime: file.uploadTime,
      fileType: file.fileType,
      downloadUrl: file.downloadUrl,
      previewUrl: file.previewUrl,
      markedImportant: file.markedImportant,
      isNew: file.isNew,
      supportsReadState: true,
      localDownloadState: file.localDownloadState,
      localFilePath: file.localFilePath,
    );
  }

  factory FileDetailItem.fromAttachment({
    required FileAttachment attachment,
    required String courseId,
    required String courseName,
    db.CachedAsset? cachedAsset,
    String uploadTime = '',
  }) {
    return FileDetailItem(
      cacheKey: attachment.cacheKeyForCourse(courseId),
      sourceKind: attachment.kind.name,
      courseId: courseId,
      courseName: courseName,
      title: attachment.name,
      description: '',
      rawSize: 0,
      size: attachment.size,
      uploadTime: uploadTime,
      fileType: attachment.fileType,
      downloadUrl: attachment.downloadUrl,
      previewUrl: attachment.previewUrl,
      markedImportant: false,
      isNew: false,
      supportsReadState: false,
      localDownloadState: cachedAsset != null ? 'downloaded' : 'none',
      localFilePath: cachedAsset?.localPath,
    );
  }

  factory FileDetailItem.fromCachedAssetListItem(CachedAssetListItem asset) {
    final routeData = asset.routeData;
    final attachment = routeData?.attachment;
    if (attachment == null) {
      throw ArgumentError(
        'Cached asset detail items require attachment route metadata.',
        'asset',
      );
    }
    return FileDetailItem.fromAttachment(
      attachment: attachment,
      courseId: asset.courseId,
      courseName: asset.courseName,
      cachedAsset: db.CachedAsset(
        assetKey: asset.assetKey,
        courseId: asset.courseId,
        title: asset.title,
        fileType: asset.fileType,
        localPath: asset.localPath,
        fileSizeBytes: asset.diskSizeBytes,
        lastAccessedAt: asset.lastAccessedAt,
        updatedAt: asset.updatedAt,
        persistedFileId: null,
        sourceKind: asset.sourceKind,
        routeDataJson: routeData!.toJsonString(),
      ),
      uploadTime: asset.activityTime ?? '',
    );
  }

  final String cacheKey;
  final String sourceKind;
  final String? persistedFileId;
  final String courseId;
  final String courseName;
  final String title;
  final String description;
  final int rawSize;
  final String size;
  final String uploadTime;
  final String fileType;
  final String downloadUrl;
  final String previewUrl;
  final bool markedImportant;
  final bool isNew;
  final bool supportsReadState;
  final String localDownloadState;
  final String? localFilePath;

  FileDetailRouteData get routeData {
    if (persistedFileId != null &&
        persistedFileId!.isNotEmpty &&
        sourceKind == 'courseFile') {
      return FileDetailRouteData.courseFile(
        fileId: persistedFileId!,
        courseId: courseId,
        courseName: courseName,
      );
    }

    return FileDetailRouteData.attachment(
      attachment: FileAttachment(
        id: _attachmentIdFromCacheKey(cacheKey),
        name: title,
        downloadUrl: downloadUrl,
        previewUrl: previewUrl,
        size: size,
        kind: fileAttachmentKindFromName(sourceKind),
      ),
      courseId: courseId,
      courseName: courseName,
    );
  }
}

class CachedAssetListItem {
  const CachedAssetListItem({
    required this.assetKey,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.fileType,
    required this.localPath,
    required this.diskSizeBytes,
    required this.sourceKind,
    required this.updatedAt,
    this.lastAccessedAt,
    this.routeData,
  });

  factory CachedAssetListItem.fromCachedAsset(
    db.CachedAsset asset, {
    required String courseName,
  }) {
    return CachedAssetListItem(
      assetKey: asset.assetKey,
      courseId: asset.courseId,
      courseName: courseName,
      title: asset.title,
      fileType: asset.fileType,
      localPath: asset.localPath,
      diskSizeBytes: asset.fileSizeBytes,
      sourceKind: asset.sourceKind,
      updatedAt: asset.updatedAt,
      lastAccessedAt: asset.lastAccessedAt,
      routeData:
          FileDetailRouteData.tryParseJsonString(asset.routeDataJson) ??
          _fallbackRouteDataForCachedAsset(asset, courseName: courseName),
    );
  }

  final String assetKey;
  final String courseId;
  final String courseName;
  final String title;
  final String fileType;
  final String localPath;
  final int diskSizeBytes;
  final String sourceKind;
  final String updatedAt;
  final String? lastAccessedAt;
  final FileDetailRouteData? routeData;

  bool get canOpenDetail => routeData != null;
  String? get activityTime => lastAccessedAt ?? updatedAt;
}

String _attachmentIdFromCacheKey(String cacheKey) {
  final separatorIndex = cacheKey.lastIndexOf(':');
  if (separatorIndex == -1 || separatorIndex >= cacheKey.length - 1) {
    return cacheKey;
  }
  return cacheKey.substring(separatorIndex + 1);
}

FileDetailRouteData? _fallbackRouteDataForCachedAsset(
  db.CachedAsset asset, {
  required String courseName,
}) {
  final persistedFileId = asset.persistedFileId;
  if (persistedFileId == null || persistedFileId.isEmpty) {
    return null;
  }
  return FileDetailRouteData.courseFile(
    fileId: persistedFileId,
    courseId: asset.courseId,
    courseName: courseName,
  );
}
