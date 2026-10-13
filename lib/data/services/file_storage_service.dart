import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies picked media into app-private storage so attachments survive even
/// when the source (gallery, camera cache) is cleaned up (Spec §4C/§4D).
class FileStorageService {
  FileStorageService._();
  static final FileStorageService instance = FileStorageService._();

  static const Uuid _uuid = Uuid();

  Directory? _attachmentsDir;

  Future<Directory> attachmentsDir() async {
    if (_attachmentsDir != null && _attachmentsDir!.existsSync()) {
      return _attachmentsDir!;
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, 'attachments'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _attachmentsDir = dir;
    return dir;
  }

  /// Copies [sourcePath] into private storage and returns the new absolute path.
  Future<String> persist(String sourcePath, {String? extension}) async {
    final Directory dir = await attachmentsDir();
    final String ext = extension ??
        (p.extension(sourcePath).isEmpty ? '' : p.extension(sourcePath));
    final String name = '${_uuid.v4()}$ext';
    final String dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Writes raw [bytes] (e.g. a drawing) into private storage.
  Future<String> persistBytes(List<int> bytes, {required String extension}) async {
    final Directory dir = await attachmentsDir();
    final String name = '${_uuid.v4()}.$extension';
    final String dest = p.join(dir.path, name);
    await File(dest).writeAsBytes(bytes);
    return dest;
  }

  Future<void> delete(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Total bytes used by attachments, for the Storage usage row (Spec §12).
  Future<int> attachmentsSize() async {
    final Directory dir = await attachmentsDir();
    int total = 0;
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
