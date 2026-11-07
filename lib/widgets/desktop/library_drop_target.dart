import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mornye/utils/audio_format_utils.dart';

@visibleForTesting
List<String> libraryFoldersForDrop(
  Iterable<String> paths, {
  required bool Function(String path) isDirectory,
}) {
  final folders = <String>{};
  for (final raw in paths) {
    final path = _trimSeparator(raw.trim());
    if (path.isEmpty) continue;
    if (isDirectory(path)) {
      folders.add(path);
    } else if (audioFormatForPath(path) != null) {
      folders.add(File(path).parent.path);
    }
  }
  final sorted = folders.toList()..sort((a, b) => a.length.compareTo(b.length));
  final kept = <String>[];
  for (final folder in sorted) {
    final covered = kept.any(
      (outer) => folder.startsWith('$outer${Platform.pathSeparator}'),
    );
    if (!covered) kept.add(folder);
  }
  return kept;
}

String _trimSeparator(String path) {
  final separator = Platform.pathSeparator;
  if (path.length > 1 && path.endsWith(separator) && !path.endsWith(':\\')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}

class DesktopLibraryDropTarget extends StatelessWidget {
  const DesktopLibraryDropTarget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
