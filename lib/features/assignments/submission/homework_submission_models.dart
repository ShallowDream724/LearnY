import '../../../core/database/database.dart' as db;

enum HomeworkSubmissionStatus { idle, submitting, success, failure }

class HomeworkSubmissionSeed {
  const HomeworkSubmissionSeed({
    required this.homeworkId,
    required this.initialContent,
    required this.hasExistingAttachment,
  });

  factory HomeworkSubmissionSeed.fromHomework(db.Homework homework) {
    return HomeworkSubmissionSeed(
      homeworkId: homework.id,
      initialContent: normalizeHomeworkSubmissionContent(
        homework.submittedContent,
      ),
      hasExistingAttachment:
          homework.submittedAttachmentJson != null &&
          homework.submittedAttachmentJson!.isNotEmpty,
    );
  }

  final String homeworkId;
  final String initialContent;
  final bool hasExistingAttachment;

  @override
  bool operator ==(Object other) {
    return other is HomeworkSubmissionSeed &&
        other.homeworkId == homeworkId &&
        other.initialContent == initialContent &&
        other.hasExistingAttachment == hasExistingAttachment;
  }

  @override
  int get hashCode =>
      Object.hash(homeworkId, initialContent, hasExistingAttachment);
}

class HomeworkSubmissionAttachment {
  const HomeworkSubmissionAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

class HomeworkSubmissionRequest {
  const HomeworkSubmissionRequest({
    required this.homeworkId,
    this.content = '',
    this.attachmentPath,
    this.attachmentName,
    this.removeAttachment = false,
  });

  final String homeworkId;
  final String content;
  final String? attachmentPath;
  final String? attachmentName;
  final bool removeAttachment;
}

class HomeworkSubmissionState {
  const HomeworkSubmissionState({
    required this.seed,
    required this.content,
    this.attachment,
    this.removeExistingAttachment = false,
    this.status = HomeworkSubmissionStatus.idle,
    this.errorMessage,
  });

  factory HomeworkSubmissionState.initial(HomeworkSubmissionSeed seed) {
    return HomeworkSubmissionState(seed: seed, content: seed.initialContent);
  }

  final HomeworkSubmissionSeed seed;
  final String content;
  final HomeworkSubmissionAttachment? attachment;
  final bool removeExistingAttachment;
  final HomeworkSubmissionStatus status;
  final String? errorMessage;

  static const _sentinel = Object();

  bool get isSubmitting => status == HomeworkSubmissionStatus.submitting;
  bool get hasSelectedAttachment => attachment != null;
  bool get hasExistingAttachment =>
      seed.hasExistingAttachment &&
      !removeExistingAttachment &&
      attachment == null;
  bool get hasContent =>
      content.trim().isNotEmpty ||
      hasSelectedAttachment ||
      (seed.hasExistingAttachment && removeExistingAttachment);
  bool get hasUnsavedChanges =>
      content.trim() != seed.initialContent ||
      hasSelectedAttachment ||
      removeExistingAttachment;
  int get characterCount => content.length;

  HomeworkSubmissionRequest toRequest() {
    return HomeworkSubmissionRequest(
      homeworkId: seed.homeworkId,
      content: content.trim(),
      attachmentPath: attachment?.path,
      attachmentName: attachment?.name,
      removeAttachment: removeExistingAttachment && attachment == null,
    );
  }

  HomeworkSubmissionState copyWith({
    String? content,
    Object? attachment = _sentinel,
    bool? removeExistingAttachment,
    HomeworkSubmissionStatus? status,
    Object? errorMessage = _sentinel,
  }) {
    return HomeworkSubmissionState(
      seed: seed,
      content: content ?? this.content,
      attachment: identical(attachment, _sentinel)
          ? this.attachment
          : attachment as HomeworkSubmissionAttachment?,
      removeExistingAttachment:
          removeExistingAttachment ?? this.removeExistingAttachment,
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

String normalizeHomeworkSubmissionContent(String? html) {
  if (html == null || html.isEmpty) {
    return '';
  }
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .trim();
}
