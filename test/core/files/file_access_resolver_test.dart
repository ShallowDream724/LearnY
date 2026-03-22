import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_access_resolver.dart';

void main() {
  group('FileAccessResolver', () {
    const resolver = FileAccessResolver();

    test('appends explicit extension when title is missing one', () {
      final descriptor = resolver.resolve(
        title: 'lecture_notes',
        fileType: 'pdf',
      );

      expect(descriptor.displayName, 'lecture_notes.pdf');
      expect(descriptor.storedFileName, 'lecture_notes.pdf');
      expect(descriptor.extension, 'pdf');
      expect(descriptor.mimeType, 'application/pdf');
    });

    test('keeps existing extension and sanitizes invalid characters', () {
      final descriptor = resolver.resolve(
        title: 'week1:soil/mechanics?.pptx',
        fileType: 'pptx',
      );

      expect(descriptor.displayName, 'week1:soil/mechanics?.pptx');
      expect(descriptor.storedFileName, 'week1_soil_mechanics_.pptx');
      expect(descriptor.extension, 'pptx');
      expect(
        descriptor.mimeType,
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      );
    });
  });
}
