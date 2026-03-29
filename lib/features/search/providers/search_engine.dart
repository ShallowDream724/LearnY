import 'package:pinyin/pinyin.dart';

import 'search_models.dart';

class SearchField {
  const SearchField(
    this.text, {
    required this.weight,
    this.isPrimary = false,
  });

  final String text;
  final double weight;
  final bool isPrimary;
}

class SearchDocument {
  SearchDocument({
    required this.result,
    required this.fields,
    this.fileExtension,
  }) : _indexedFields = fields.map(_IndexedSearchField.fromField).toList();

  final SearchResult result;
  final List<SearchField> fields;
  final String? fileExtension;
  final List<_IndexedSearchField> _indexedFields;

  bool get isFavorite => result.isFavorite;
  bool get isDownloaded => result.isDownloaded;

  bool get isFileLike => switch (result.kind) {
    SearchResultKind.course => false,
    SearchResultKind.notification => false,
    SearchResultKind.homework => false,
    SearchResultKind.courseFile => true,
    SearchResultKind.notificationAttachment => true,
    SearchResultKind.homeworkAttachment => true,
    SearchResultKind.homeworkSubmittedAttachment => true,
    SearchResultKind.homeworkGradeAttachment => true,
    SearchResultKind.homeworkAnswerAttachment => true,
  };
}

class SearchEngine {
  const SearchEngine();

  List<SearchResult> search({
    required List<SearchDocument> documents,
    required String query,
  }) {
    final parsed = _ParsedQuery.parse(query);
    if (parsed.tokens.isEmpty &&
        !parsed.wantsFavorites &&
        !parsed.wantsDownloaded &&
        !parsed.wantsNotifications &&
        !parsed.wantsHomeworks &&
        !parsed.wantsFiles &&
        !parsed.wantsAttachments &&
        parsed.extensionFilters.isEmpty &&
        !parsed.wantsImages) {
      return const <SearchResult>[];
    }

    final exactMatches = <_ScoredDocument>[];
    final exactKeys = <String>{};
    for (final document in documents) {
      final match = _scoreDocument(document, parsed.tokens);
      if (match == null) {
        continue;
      }
      exactMatches.add(match);
      exactKeys.add(document.result.key);
    }
    exactMatches.sort(_compareScoredDocuments);

    final results = <SearchResult>[];
    results.addAll(
      exactMatches.map(
        (match) => match.document.result.copyWith(
          section: buildExactSectionMeta(match.document.result.kind),
        ),
      ),
    );

    final suggestedBuckets = <_SectionBucket>[];

    void addBucket({
      required String idSuffix,
      required String title,
      required SearchResultKind sectionKind,
      required int order,
      required bool Function(SearchDocument document) predicate,
    }) {
      final bucketMatches = <_ScoredDocument>[];
      for (final document in documents) {
        if (exactKeys.contains(document.result.key) || !predicate(document)) {
          continue;
        }
        if (!_matchesContentRefinement(document, parsed.contentTokens)) {
          continue;
        }
        final score =
            _scoreDocument(document, parsed.contentTokens)?.score ??
            _fallbackSuggestionScore(document, parsed);
        bucketMatches.add(_ScoredDocument(document: document, score: score));
      }
      if (bucketMatches.isEmpty) {
        return;
      }
      bucketMatches.sort(_compareScoredDocuments);
      suggestedBuckets.add(
        _SectionBucket(
          meta: buildRelatedSectionMeta(
            idSuffix: idSuffix,
            title: title,
            kind: sectionKind,
            order: order,
          ),
          results: bucketMatches
              .map(
                (match) =>
                    match.document.result.copyWith(
                      section: buildRelatedSectionMeta(
                        idSuffix: idSuffix,
                        title: title,
                        kind: sectionKind,
                        order: order,
                      ),
                    ),
              )
              .toList(growable: false),
        ),
      );
    }

    if (parsed.wantsFavorites) {
      addBucket(
        idSuffix: 'favorites',
        title: '已收藏文件',
        sectionKind: SearchResultKind.courseFile,
        order: 0,
        predicate: (document) => document.isFileLike && document.isFavorite,
      );
    }

    if (parsed.wantsDownloaded) {
      addBucket(
        idSuffix: 'downloaded',
        title: '已下载文件',
        sectionKind: SearchResultKind.courseFile,
        order: 10,
        predicate: (document) => document.isFileLike && document.isDownloaded,
      );
    }

    if (parsed.wantsImages) {
      addBucket(
        idSuffix: 'images',
        title: '图片',
        sectionKind: SearchResultKind.courseFile,
        order: 20,
        predicate: (document) =>
            document.isFileLike &&
            _imageExtensions.contains(document.fileExtension),
      );
    }

    for (final extension in parsed.extensionFilters) {
      addBucket(
        idSuffix: 'ext:$extension',
        title: _extensionSectionTitle(extension),
        sectionKind: SearchResultKind.courseFile,
        order: 30 + parsed.extensionFilters.indexOf(extension) * 10,
        predicate: (document) =>
            document.isFileLike && document.fileExtension == extension,
      );
    }

    if (parsed.wantsNotifications) {
      addBucket(
        idSuffix: 'notifications',
        title: '相关通知',
        sectionKind: SearchResultKind.notification,
        order: 200,
        predicate: (document) => document.result.kind == SearchResultKind.notification,
      );
    }

    if (parsed.wantsHomeworks) {
      addBucket(
        idSuffix: 'homeworks',
        title: '相关作业',
        sectionKind: SearchResultKind.homework,
        order: 210,
        predicate: (document) => document.result.kind == SearchResultKind.homework,
      );
    }

    if (parsed.wantsFiles) {
      addBucket(
        idSuffix: 'files',
        title: '相关文件',
        sectionKind: SearchResultKind.courseFile,
        order: 220,
        predicate: (document) => document.result.kind == SearchResultKind.courseFile,
      );
    }

    if (parsed.wantsAttachments) {
      addBucket(
        idSuffix: 'notification-attachments',
        title: '通知附件',
        sectionKind: SearchResultKind.notificationAttachment,
        order: 300,
        predicate: (document) =>
            document.result.kind == SearchResultKind.notificationAttachment,
      );
      addBucket(
        idSuffix: 'homework-attachments',
        title: '作业附件',
        sectionKind: SearchResultKind.homeworkAttachment,
        order: 310,
        predicate: (document) =>
            document.result.kind == SearchResultKind.homeworkAttachment,
      );
      addBucket(
        idSuffix: 'submitted-attachments',
        title: '提交附件',
        sectionKind: SearchResultKind.homeworkSubmittedAttachment,
        order: 320,
        predicate: (document) =>
            document.result.kind == SearchResultKind.homeworkSubmittedAttachment,
      );
      addBucket(
        idSuffix: 'grade-attachments',
        title: '教师反馈附件',
        sectionKind: SearchResultKind.homeworkGradeAttachment,
        order: 330,
        predicate: (document) =>
            document.result.kind == SearchResultKind.homeworkGradeAttachment,
      );
      addBucket(
        idSuffix: 'answer-attachments',
        title: '参考答案附件',
        sectionKind: SearchResultKind.homeworkAnswerAttachment,
        order: 340,
        predicate: (document) =>
            document.result.kind == SearchResultKind.homeworkAnswerAttachment,
      );
    }

    suggestedBuckets.sort((a, b) => a.meta.order.compareTo(b.meta.order));
    for (final bucket in suggestedBuckets) {
      results.addAll(bucket.results);
    }

    return results;
  }
}

class _SectionBucket {
  const _SectionBucket({required this.meta, required this.results});

  final SearchSectionMeta meta;
  final List<SearchResult> results;
}

class _ScoredDocument {
  const _ScoredDocument({
    required this.document,
    required this.score,
    this.matchedPrimary = false,
    this.matchedTokenCount = 0,
  });

  final SearchDocument document;
  final double score;
  final bool matchedPrimary;
  final int matchedTokenCount;
}

class _ParsedQuery {
  const _ParsedQuery({
    required this.tokens,
    required this.contentTokens,
    required this.extensionFilters,
    required this.wantsFavorites,
    required this.wantsDownloaded,
    required this.wantsNotifications,
    required this.wantsHomeworks,
    required this.wantsFiles,
    required this.wantsAttachments,
    required this.wantsImages,
  });

  factory _ParsedQuery.parse(String rawQuery) {
    final seen = <String>{};
    final tokens = <String>[];
    final contentTokens = <String>[];
    final extensions = <String>[];
    var wantsFavorites = false;
    var wantsDownloaded = false;
    var wantsNotifications = false;
    var wantsHomeworks = false;
    var wantsFiles = false;
    var wantsAttachments = false;
    var wantsImages = false;

    for (final token in _tokenize(rawQuery)) {
      if (!seen.add(token)) {
        continue;
      }
      tokens.add(token);

      final extension = _canonicalExtension(token);
      final isIntentWord =
          _favoriteTokens.contains(token) ||
          _downloadedTokens.contains(token) ||
          _notificationTokens.contains(token) ||
          _homeworkTokens.contains(token) ||
          _fileTokens.contains(token) ||
          _attachmentTokens.contains(token) ||
          _imageIntentTokens.contains(token) ||
          extension != null;

      if (_favoriteTokens.contains(token)) {
        wantsFavorites = true;
      }
      if (_downloadedTokens.contains(token)) {
        wantsDownloaded = true;
      }
      if (_notificationTokens.contains(token)) {
        wantsNotifications = true;
      }
      if (_homeworkTokens.contains(token)) {
        wantsHomeworks = true;
      }
      if (_fileTokens.contains(token)) {
        wantsFiles = true;
      }
      if (_attachmentTokens.contains(token)) {
        wantsAttachments = true;
      }
      if (_imageIntentTokens.contains(token)) {
        wantsImages = true;
      }
      if (extension != null && !extensions.contains(extension)) {
        extensions.add(extension);
      }
      if (!isIntentWord) {
        contentTokens.add(token);
      }
    }

    return _ParsedQuery(
      tokens: tokens,
      contentTokens: contentTokens,
      extensionFilters: extensions,
      wantsFavorites: wantsFavorites,
      wantsDownloaded: wantsDownloaded,
      wantsNotifications: wantsNotifications,
      wantsHomeworks: wantsHomeworks,
      wantsFiles: wantsFiles,
      wantsAttachments: wantsAttachments,
      wantsImages: wantsImages,
    );
  }

  final List<String> tokens;
  final List<String> contentTokens;
  final List<String> extensionFilters;
  final bool wantsFavorites;
  final bool wantsDownloaded;
  final bool wantsNotifications;
  final bool wantsHomeworks;
  final bool wantsFiles;
  final bool wantsAttachments;
  final bool wantsImages;
}

class _IndexedSearchField {
  _IndexedSearchField({
    required this.weight,
    required this.isPrimary,
    required this.normalized,
    required this.compact,
    required this.pinyin,
    required this.initials,
  });

  factory _IndexedSearchField.fromField(SearchField field) {
    final normalized = _normalizeText(field.text);
    final compact = _compactText(normalized);
    final containsChinese = _containsChinese(field.text);
    final pinyin = containsChinese
        ? _compactText(
            PinyinHelper.getPinyinE(
              field.text,
              separator: '',
              defPinyin: '',
              format: PinyinFormat.WITHOUT_TONE,
            ),
          )
        : compact;
    final initials = containsChinese
        ? _compactText(PinyinHelper.getShortPinyin(field.text))
        : compact;
    return _IndexedSearchField(
      weight: field.weight,
      isPrimary: field.isPrimary,
      normalized: normalized,
      compact: compact,
      pinyin: pinyin,
      initials: initials,
    );
  }

  final double weight;
  final bool isPrimary;
  final String normalized;
  final String compact;
  final String pinyin;
  final String initials;
}

_ScoredDocument? _scoreDocument(SearchDocument document, List<String> tokens) {
  if (tokens.isEmpty) {
    return null;
  }

  var total = 0.0;
  var matchedPrimary = false;
  var matchedTokenCount = 0;

  for (final token in tokens) {
    final tokenScore = _scoreToken(document, token);
    if (tokenScore == null) {
      continue;
    }
    total += tokenScore.score;
    matchedPrimary = matchedPrimary || tokenScore.matchedPrimary;
    matchedTokenCount += 1;
  }

  if (matchedTokenCount == 0) {
    return null;
  }

  total += matchedTokenCount > 1 ? (matchedTokenCount - 1) * 3.5 : 0.0;
  if (matchedPrimary) {
    total += 1.5;
  }

  return _ScoredDocument(
    document: document,
    score: total,
    matchedPrimary: matchedPrimary,
    matchedTokenCount: matchedTokenCount,
  );
}

_FieldTokenScore? _scoreToken(SearchDocument document, String token) {
  _FieldTokenScore? best;
  for (final field in document._indexedFields) {
    final score = _scoreTokenAgainstField(token, field);
    if (score <= 0) {
      continue;
    }
    if (best == null || score > best.score) {
      best = _FieldTokenScore(score: score, matchedPrimary: field.isPrimary);
    }
  }
  return best;
}

double _scoreTokenAgainstField(String token, _IndexedSearchField field) {
  final normalizedToken = _normalizeText(token);
  final compactToken = _compactText(token);
  if (normalizedToken.isEmpty || compactToken.isEmpty) {
    return 0;
  }

  if (field.normalized == normalizedToken) {
    return field.weight * 8;
  }
  if (field.normalized.startsWith(normalizedToken)) {
    return field.weight * 6.5;
  }
  if (field.normalized.contains(normalizedToken)) {
    return field.weight * 5;
  }
  if (compactToken.length >= 2 && field.compact.contains(compactToken)) {
    return field.weight * 4.4;
  }
  if (compactToken.length >= 2 && field.pinyin.contains(compactToken)) {
    return field.weight * 4.0;
  }
  if (compactToken.length >= 2 && field.initials.startsWith(compactToken)) {
    return field.weight * 3.5;
  }
  if (compactToken.length >= 2 && _isSubsequence(compactToken, field.initials)) {
    return field.weight * 2.8;
  }
  if (compactToken.length >= 3 && _isSubsequence(compactToken, field.compact)) {
    return field.weight * 2.1;
  }
  return 0;
}

bool _matchesContentRefinement(SearchDocument document, List<String> contentTokens) {
  if (contentTokens.isEmpty) {
    return true;
  }
  return _scoreDocument(document, contentTokens) != null;
}

double _fallbackSuggestionScore(SearchDocument document, _ParsedQuery query) {
  var score = 1.0;
  if (document.isFavorite && query.wantsFavorites) {
    score += 1;
  }
  if (document.isDownloaded && query.wantsDownloaded) {
    score += 1;
  }
  if (query.wantsImages && _imageExtensions.contains(document.fileExtension)) {
    score += 0.5;
  }
  if (document.result.isFavorite) {
    score += 0.2;
  }
  if (document.result.isDownloaded) {
    score += 0.2;
  }
  return score;
}

int _compareScoredDocuments(_ScoredDocument left, _ScoredDocument right) {
  final sectionOrder = searchResultKindBaseOrder(
    left.document.result.kind,
  ).compareTo(searchResultKindBaseOrder(right.document.result.kind));
  if (sectionOrder != 0) {
    return sectionOrder;
  }

  final scoreOrder = right.score.compareTo(left.score);
  if (scoreOrder != 0) {
    return scoreOrder;
  }

  final titleOrder = left.document.result.title.compareTo(right.document.result.title);
  if (titleOrder != 0) {
    return titleOrder;
  }

  return left.document.result.key.compareTo(right.document.result.key);
}

Iterable<String> _tokenize(String rawQuery) sync* {
  for (final chunk in rawQuery.split(_tokenSplitPattern)) {
    final cleaned = _normalizeToken(chunk);
    if (cleaned.isEmpty) {
      continue;
    }
    yield cleaned;
    for (final nested in cleaned.split(_nestedTokenPattern)) {
      final normalizedNested = _normalizeToken(nested);
      if (normalizedNested.isNotEmpty && normalizedNested != cleaned) {
        yield normalizedNested;
      }
    }
  }
}

String _normalizeToken(String value) {
  var normalized = _normalizeText(value);
  normalized = normalized.replaceAll(_trimPunctuationPattern, '');
  if (normalized.startsWith('.')) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

String _normalizeText(String value) => value.trim().toLowerCase();

String _compactText(String value) =>
    _normalizeText(value).replaceAll(_compactPattern, '');

bool _containsChinese(String value) => _hanPattern.hasMatch(value);

bool _isSubsequence(String needle, String haystack) {
  if (needle.isEmpty) {
    return true;
  }
  var index = 0;
  for (final codeUnit in haystack.codeUnits) {
    if (codeUnit == needle.codeUnitAt(index)) {
      index += 1;
      if (index == needle.length) {
        return true;
      }
    }
  }
  return false;
}

String? _canonicalExtension(String token) => _extensionAliases[token];

String _extensionSectionTitle(String extension) {
  return switch (extension) {
    'pdf' => 'PDF 文件',
    'doc' || 'docx' || 'docm' => 'Word 文档',
    'xls' || 'xlsx' || 'xlsm' => 'Excel 表格',
    'ppt' || 'pptx' || 'pptm' => '演示文稿',
    'zip' || 'rar' || '7z' => '压缩包',
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'heic' => '图片',
    _ => '${extension.toUpperCase()} 文件',
  };
}

class _FieldTokenScore {
  const _FieldTokenScore({required this.score, required this.matchedPrimary});

  final double score;
  final bool matchedPrimary;
}

const _favoriteTokens = <String>{
  '收藏',
  'favorite',
  'favorites',
  'bookmark',
  'bookmarks',
};

const _downloadedTokens = <String>{
  '下载',
  '已下载',
  'download',
  'downloaded',
  '缓存',
  '离线',
  'offline',
};

const _notificationTokens = <String>{
  '通知',
  '公告',
  'notice',
  'notices',
  'announcement',
  'announcements',
};

const _homeworkTokens = <String>{
  '作业',
  'ddl',
  '截止',
  'homework',
  'assignment',
  'assignments',
};

const _fileTokens = <String>{
  '文件',
  '资料',
  '课件',
  '文档',
  'file',
  'files',
  'document',
  'documents',
};

const _attachmentTokens = <String>{
  '附件',
  'attachment',
  'attachments',
};

const _imageIntentTokens = <String>{
  '图片',
  '照片',
  'image',
  'images',
  'photo',
  'photos',
};

const _extensionAliases = <String, String>{
  'pdf': 'pdf',
  '.pdf': 'pdf',
  'doc': 'doc',
  '.doc': 'doc',
  'docx': 'docx',
  '.docx': 'docx',
  'docm': 'docm',
  '.docm': 'docm',
  'xls': 'xls',
  '.xls': 'xls',
  'xlsx': 'xlsx',
  '.xlsx': 'xlsx',
  'xlsm': 'xlsm',
  '.xlsm': 'xlsm',
  'ppt': 'ppt',
  '.ppt': 'ppt',
  'pptx': 'pptx',
  '.pptx': 'pptx',
  'pptm': 'pptm',
  '.pptm': 'pptm',
  'zip': 'zip',
  '.zip': 'zip',
  'rar': 'rar',
  '.rar': 'rar',
  '7z': '7z',
  '.7z': '7z',
  'txt': 'txt',
  '.txt': 'txt',
  'md': 'md',
  '.md': 'md',
  'jpg': 'jpg',
  '.jpg': 'jpg',
  'jpeg': 'jpeg',
  '.jpeg': 'jpeg',
  'png': 'png',
  '.png': 'png',
  'gif': 'gif',
  '.gif': 'gif',
  'webp': 'webp',
  '.webp': 'webp',
  'heic': 'heic',
  '.heic': 'heic',
};

const _imageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'heic',
};

final _tokenSplitPattern = RegExp(r'[\s\u3000,，、;；:：|/\\]+');
final _nestedTokenPattern = RegExp(r'[_\-+.]+');
final _trimPunctuationPattern = RegExp(
  r"""^[`~!@#%^&*()=+\[\]{}<>?'"“”‘’]+|[`~!@#%^&*()=+\[\]{}<>?'"“”‘’]+$""",
);
final _compactPattern = RegExp(r'[^0-9a-z\u3400-\u9fff]+');
final _hanPattern = RegExp(r'[\u3400-\u9fff]');
