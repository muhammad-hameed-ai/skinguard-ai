import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// image_picker returns a path inside the app cache directory, which Android
/// may clear at any time — under memory pressure, on process death, or
/// between the pick and the read. Every picked image must therefore be copied
/// into permanent storage before anything else touches it.
class ImageStorage {
  static Future<File> persist(File picked) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'scans'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    final name = 'scan_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, name));

    // copy(), not rename() — rename fails across filesystem boundaries,
    // and cache and documents are not guaranteed to be on the same one.
    return picked.copy(dest.path);
  }
}
