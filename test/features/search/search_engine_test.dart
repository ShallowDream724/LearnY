import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/features/search/providers/search_engine.dart';
import 'package:learn_y/features/search/providers/search_models.dart';

void main() {
  const engine = SearchEngine();

  SearchDocument buildDocument({
    required String key,
    required SearchResultKind kind,
    required String title,
    required List<SearchField> fields,
    SearchNavigationType navigationType = SearchNavigationType.courseDetail,
    bool isFavorite = false,
    bool isDownloaded = false,
    String? fileExtension,
  }) {
    return SearchDocument(
      result: SearchResult(
        key: key,
        kind: kind,
        navigationType: navigationType,
        id: key,
        courseId: 'course-1',
        courseName: '土力学',
        title: title,
        subtitle: '土力学',
        section: buildExactSectionMeta(kind),
        isFavorite: isFavorite,
        isDownloaded: isDownloaded,
      ),
      fields: fields,
      fileExtension: fileExtension,
    );
  }

  test('matches chinese content by full pinyin and initials', () {
    final documents = [
      buildDocument(
        key: 'course:tuli',
        kind: SearchResultKind.course,
        title: '土力学',
        fields: const [
          SearchField('土力学', weight: 4, isPrimary: true, enablePhonetic: true),
        ],
      ),
    ];

    final fullPinyinResults = engine.search(
      documents: documents,
      query: 'tulixue',
    );
    final initialsResults = engine.search(documents: documents, query: 'tlx');

    expect(fullPinyinResults.single.title, '土力学');
    expect(initialsResults.single.title, '土力学');
  });

  test('surfaces favorites as related results for 收藏 intent', () {
    final documents = [
      buildDocument(
        key: 'file:fav',
        kind: SearchResultKind.courseFile,
        title: 'slides.pdf',
        navigationType: SearchNavigationType.fileDetail,
        isFavorite: true,
        fields: const [
          SearchField('slides.pdf', weight: 4, isPrimary: true),
          SearchField('讲义', weight: 2.5),
        ],
        fileExtension: 'pdf',
      ),
      buildDocument(
        key: 'file:plain',
        kind: SearchResultKind.courseFile,
        title: 'notes.pdf',
        navigationType: SearchNavigationType.fileDetail,
        fields: const [SearchField('notes.pdf', weight: 4, isPrimary: true)],
        fileExtension: 'pdf',
      ),
    ];

    final results = engine.search(documents: documents, query: '收藏');

    expect(results, hasLength(1));
    expect(results.single.title, 'slides.pdf');
    expect(results.single.section.kind, SearchSectionKind.related);
    expect(results.single.section.title, '已收藏文件');
  });

  test('keeps attachment keyword hits in exact attachment sections', () {
    final documents = [
      buildDocument(
        key: 'attachment:hw',
        kind: SearchResultKind.homeworkAttachment,
        title: '有限元作业附件.pdf',
        navigationType: SearchNavigationType.fileDetail,
        fields: const [
          SearchField('有限元作业附件.pdf', weight: 4, isPrimary: true),
          SearchField('作业附件', weight: 2.8),
        ],
        fileExtension: 'pdf',
      ),
    ];

    final results = engine.search(documents: documents, query: '附件');

    expect(results, hasLength(1));
    expect(results.single.section.kind, SearchSectionKind.keyword);
    expect(results.single.section.title, '作业附件');
  });

  test('uses any-term matching and ranks multi-hit results first', () {
    final documents = [
      buildDocument(
        key: 'course:both',
        kind: SearchResultKind.course,
        title: '土力学有限元',
        fields: const [
          SearchField(
            '土力学有限元',
            weight: 4,
            isPrimary: true,
            enablePhonetic: true,
          ),
        ],
      ),
      buildDocument(
        key: 'course:single',
        kind: SearchResultKind.course,
        title: '土力学实验',
        fields: const [
          SearchField(
            '土力学实验',
            weight: 4,
            isPrimary: true,
            enablePhonetic: true,
          ),
        ],
      ),
    ];

    final results = engine.search(documents: documents, query: '土力学 有限元');

    expect(results, hasLength(2));
    expect(results.first.title, '土力学有限元');
  });

  test('keeps keyword hits ahead of related intent results', () {
    final documents = [
      buildDocument(
        key: 'notification:related',
        kind: SearchResultKind.notification,
        title: '课程安排',
        navigationType: SearchNavigationType.notificationDetail,
        fields: const [SearchField('课程安排', weight: 4, isPrimary: true)],
      ),
      buildDocument(
        key: 'file:pdf',
        kind: SearchResultKind.courseFile,
        title: '有限元讲义.pdf',
        navigationType: SearchNavigationType.fileDetail,
        fileExtension: 'pdf',
        fields: const [
          SearchField('有限元讲义.pdf', weight: 4, isPrimary: true),
          SearchField('土力学', weight: 2.5),
          SearchField('pdf', weight: 2.2),
        ],
      ),
    ];

    final results = engine.search(documents: documents, query: 'pdf 通知');

    final firstRelatedIndex = results.indexWhere(
      (result) => result.section.kind == SearchSectionKind.related,
    );

    expect(firstRelatedIndex, greaterThan(0));
    expect(
      results
          .take(firstRelatedIndex)
          .every((result) => result.section.kind == SearchSectionKind.keyword),
      isTrue,
    );
    expect(results.any((result) => result.title == '有限元讲义.pdf'), isTrue);
    expect(results[firstRelatedIndex].title, '课程安排');
    expect(results[firstRelatedIndex].section.title, '相关通知');
  });
}
