import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:mornye/services/platform_bridge.dart';

/// Extracted image data from a raw METADATA_BLOCK_PICTURE.
class ExtractedPicture {
  final String mime;
  final Uint8List data;
  final int pictureType;
  final String description;
  final int width;
  final int height;
  final int colorDepth;

  const ExtractedPicture({
    required this.mime,
    required this.data,
    this.pictureType = 3,
    this.description = '',
    this.width = 0,
    this.height = 0,
    this.colorDepth = 0,
  });
}

/// Offline Vorbis comment lyrics export result.
class VorbisLrcExportResult {
  final String lrcPath;
  final String lyrics;

  const VorbisLrcExportResult({
    required this.lrcPath,
    required this.lyrics,
  });
}

/// Extractor for FLAC / Vorbis comment METADATA_BLOCK_PICTURE.
class MetadataBlockPictureExtractor {
  /// Extracts raw cover art from binary or base64-encoded METADATA_BLOCK_PICTURE.
  static ExtractedPicture? extract(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    Uint8List raw = bytes;

    // Check if the input is base64-encoded (e.g. from Vorbis comment tag)
    if (_isBase64Candidate(bytes)) {
      try {
        final text = utf8.decode(bytes).replaceAll(RegExp(r'\s+'), '');
        raw = base64Decode(text);
      } catch (_) {
        // Fall back to attempting raw binary interpretation
        raw = bytes;
      }
    }

    if (raw.length < 32) return null;

    try {
      final data = ByteData.sublistView(raw);
      int offset = 0;

      final pictureType = data.getUint32(offset, Endian.big);
      offset += 4;

      final mimeLen = data.getUint32(offset, Endian.big);
      offset += 4;

      if (offset + mimeLen > raw.length) return null;
      final mime = utf8.decode(raw.sublist(offset, offset + mimeLen));
      offset += mimeLen;

      if (offset + 4 > raw.length) return null;
      final descLen = data.getUint32(offset, Endian.big);
      offset += 4;

      if (offset + descLen > raw.length) return null;
      final desc = utf8.decode(raw.sublist(offset, offset + descLen));
      offset += descLen;

      if (offset + 16 > raw.length) return null;
      final width = data.getUint32(offset, Endian.big);
      offset += 4;
      final height = data.getUint32(offset, Endian.big);
      offset += 4;
      final colorDepth = data.getUint32(offset, Endian.big);
      offset += 4;
      // Skip colors used count
      offset += 4;

      if (offset + 4 > raw.length) return null;
      final dataLen = data.getUint32(offset, Endian.big);
      offset += 4;

      if (dataLen == 0 || offset + dataLen > raw.length) return null;
      final pictureBytes = raw.sublist(offset, offset + dataLen);

      return ExtractedPicture(
        mime: mime.isEmpty ? 'image/jpeg' : mime,
        data: pictureBytes,
        pictureType: pictureType,
        description: desc,
        width: width,
        height: height,
        colorDepth: colorDepth,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isBase64Candidate(Uint8List bytes) {
    if (bytes.length < 4) return false;
    for (int i = 0; i < bytes.length && i < 64; i++) {
      final b = bytes[i];
      final isB64 = (b >= 65 && b <= 90) || // A-Z
          (b >= 97 && b <= 122) || // a-z
          (b >= 48 && b <= 57) || // 0-9
          b == 43 || b == 47 || b == 61 || // + / =
          b == 10 || b == 13 || b == 32; // \n \r space
      if (!isB64) return false;
    }
    return true;
  }
}

/// Offline exporter for Vorbis comments lyrics to .lrc sidecar files.
class VorbisLyricsExporter {
  /// Reads Vorbis comments from an audio file and exports them to an offline .lrc file.
  static Future<VorbisLrcExportResult> exportToLrc(
    String audioPath, {
    String? outputPath,
  }) async {
    final targetPath = (outputPath != null && outputPath.trim().isNotEmpty)
        ? outputPath
        : '${p.withoutExtension(audioPath)}.lrc';

    // Read metadata via platform bridge
    final metadata = await PlatformBridge.readFileMetadata(audioPath);
    final rawLyrics = metadata['lyrics']?.toString() ??
        metadata['syncedlyrics']?.toString() ??
        metadata['unsyncedlyrics']?.toString() ??
        metadata['comment']?.toString();

    if (rawLyrics == null || rawLyrics.trim().isEmpty) {
      throw StateError('No Vorbis lyrics found in audio metadata for $audioPath');
    }

    final lrcFile = File(targetPath);
    await lrcFile.parent.create(recursive: true);
    await lrcFile.writeAsString(rawLyrics.trim());

    return VorbisLrcExportResult(
      lrcPath: targetPath,
      lyrics: rawLyrics.trim(),
    );
  }
}
