import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';

import 'file_preview_models.dart';

class ArchiveDecodedFileEntry {
  const ArchiveDecodedFileEntry({
    required this.fileIndex,
    required this.decodedPath,
    required this.suspicious,
  });

  final int fileIndex;
  final String decodedPath;
  final bool suspicious;
}

class ArchiveNameDecodingPlan {
  const ArchiveNameDecodingPlan({
    required this.entries,
    required this.hasSuspiciousNames,
  });

  final List<ArchiveDecodedFileEntry> entries;
  final bool hasSuspiciousNames;
}

class ArchiveEntryNameDecoder {
  const ArchiveEntryNameDecoder();

  ArchiveNameDecodingPlan decode({
    required Uint8List bytes,
    required ZipDecoder decoder,
    required ArchiveNameDecodingMode mode,
  }) {
    final records = _readCentralDirectoryRecords(bytes, decoder);
    final entries = <ArchiveDecodedFileEntry>[];
    var hasSuspiciousNames = false;

    for (final record in records) {
      final candidate = _decodeFileName(
        record.fileNameBytes,
        utf8FlagSet: (record.generalPurposeBitFlag & 0x0800) != 0,
        mode: mode,
      );
      entries.add(
        ArchiveDecodedFileEntry(
          fileIndex: record.fileIndex,
          decodedPath: candidate.value,
          suspicious: candidate.suspicious,
        ),
      );
      hasSuspiciousNames = hasSuspiciousNames || candidate.suspicious;
    }

    return ArchiveNameDecodingPlan(
      entries: entries,
      hasSuspiciousNames: hasSuspiciousNames,
    );
  }

  List<_ZipCentralDirectoryRecord> _readCentralDirectoryRecords(
    Uint8List bytes,
    ZipDecoder decoder,
  ) {
    final records = <_ZipCentralDirectoryRecord>[];
    final byteData = ByteData.sublistView(bytes);
    final directory = decoder.directory;
    final start = directory.centralDirectoryOffset;
    final end = start + directory.centralDirectorySize;
    var offset = start;
    var fileIndex = 0;

    while (offset + 46 <= end && offset + 46 <= byteData.lengthInBytes) {
      if (_readUint32(byteData, offset) != _centralDirectoryHeaderSignature) {
        break;
      }

      final generalPurposeBitFlag = _readUint16(byteData, offset + 8);
      final fileNameLength = _readUint16(byteData, offset + 28);
      final extraFieldLength = _readUint16(byteData, offset + 30);
      final fileCommentLength = _readUint16(byteData, offset + 32);
      final nameStart = offset + 46;
      final nameEnd = nameStart + fileNameLength;
      if (nameEnd > byteData.lengthInBytes) {
        break;
      }

      final fileNameBytes = Uint8List.sublistView(bytes, nameStart, nameEnd);
      final isDirectory =
          fileNameBytes.isNotEmpty &&
          (fileNameBytes.last == _forwardSlash || fileNameBytes.last == _backSlash);
      if (!isDirectory) {
        records.add(
          _ZipCentralDirectoryRecord(
            fileIndex: fileIndex,
            generalPurposeBitFlag: generalPurposeBitFlag,
            fileNameBytes: fileNameBytes,
          ),
        );
        fileIndex += 1;
      }

      offset = nameEnd + extraFieldLength + fileCommentLength;
    }

    return records;
  }

  _DecodedNameCandidate _decodeFileName(
    Uint8List fileNameBytes, {
    required bool utf8FlagSet,
    required ArchiveNameDecodingMode mode,
  }) {
    final candidates = <_DecodedNameCandidate>[
      if (_tryUtf8(fileNameBytes) case final utf8Value?)
        _DecodedNameCandidate(
          encoding: _ArchiveEntryEncoding.utf8,
          value: utf8Value,
          score:
              _scoreDecodedValue(utf8Value) +
              (utf8FlagSet ? 16 : 0) +
              (mode == ArchiveNameDecodingMode.standard ? 1.5 : 0),
          suspicious: _isSuspiciousName(utf8Value),
        ),
      _DecodedNameCandidate(
        encoding: _ArchiveEntryEncoding.cp437,
        value: cp437.decode(fileNameBytes, allowInvalid: true),
        score:
            _scoreDecodedValue(cp437.decode(fileNameBytes, allowInvalid: true)) +
            (mode == ArchiveNameDecodingMode.standard ? 0.8 : 0),
        suspicious: _isSuspiciousName(
          cp437.decode(fileNameBytes, allowInvalid: true),
        ),
      ),
      _DecodedNameCandidate(
        encoding: _ArchiveEntryEncoding.gbk,
        value: gbk.decode(fileNameBytes, allowMalformed: true),
        score:
            _scoreDecodedValue(gbk.decode(fileNameBytes, allowMalformed: true)) +
            (mode == ArchiveNameDecodingMode.compatibility ? 6 : 0),
        suspicious: _isSuspiciousName(gbk.decode(fileNameBytes, allowMalformed: true)),
      ),
    ];

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first;
  }
}

class _ZipCentralDirectoryRecord {
  const _ZipCentralDirectoryRecord({
    required this.fileIndex,
    required this.generalPurposeBitFlag,
    required this.fileNameBytes,
  });

  final int fileIndex;
  final int generalPurposeBitFlag;
  final Uint8List fileNameBytes;
}

class _DecodedNameCandidate {
  const _DecodedNameCandidate({
    required this.encoding,
    required this.value,
    required this.score,
    required this.suspicious,
  });

  final _ArchiveEntryEncoding encoding;
  final String value;
  final double score;
  final bool suspicious;
}

enum _ArchiveEntryEncoding { utf8, cp437, gbk }

String? _tryUtf8(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

double _scoreDecodedValue(String value) {
  if (value.isEmpty) {
    return -100;
  }

  final chineseCount = _hanPattern.allMatches(value).length;
  final asciiUsefulCount = _asciiUsefulPattern.allMatches(value).length;
  final mojibakeCount = _mojibakePattern.allMatches(value).length;
  final replacementCount = _replacementPattern.allMatches(value).length;
  final controlCount = value.runes
      .where((rune) => rune < 0x20 && rune != 0x09 && rune != 0x0A)
      .length;

  var score = 0.0;
  score += chineseCount * 4.5;
  score += asciiUsefulCount * 1.2;
  if (chineseCount > 0) {
    score += 12;
  }
  if (mojibakeCount > 0 && chineseCount == 0) {
    score -= mojibakeCount * 5;
  }
  if (replacementCount > 0) {
    score -= replacementCount * 12;
  }
  if (controlCount > 0) {
    score -= controlCount * 20;
  }
  return score;
}

bool _isSuspiciousName(String value) {
  return value.isEmpty ||
      _replacementPattern.hasMatch(value) ||
      (_mojibakePattern.allMatches(value).length >= 2 &&
          !_hanPattern.hasMatch(value));
}

int _readUint16(ByteData data, int offset) =>
    data.getUint16(offset, Endian.little);

int _readUint32(ByteData data, int offset) =>
    data.getUint32(offset, Endian.little);

const _centralDirectoryHeaderSignature = 0x02014b50;
const _forwardSlash = 47;
const _backSlash = 92;

final _hanPattern = RegExp(r'[\u3400-\u9fff]');
final _asciiUsefulPattern = RegExp(r'[0-9A-Za-z _.\-()\[\]&+@#%,]');
final _replacementPattern = RegExp(r'[\uFFFD\uE7B3]');
final _mojibakePattern = RegExp(r'[\u00A1-\u00BF\u00C0-\u00FF]');
