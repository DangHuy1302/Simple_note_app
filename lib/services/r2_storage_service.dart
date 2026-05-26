import 'dart:async';
import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryStorageService {
  late CloudinaryPublic _cloudinary;

  CloudinaryStorageService({
    required String cloudName,
    required String uploadPreset,
  }) {
    _cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);
  }

  bool isRemoteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<String> uploadFile({
    required File file,
    required String noteId,
    required String category,
  }) async {
    try {
      final response = await _cloudinary
          .uploadFile(
            CloudinaryFile.fromFile(
              file.path,
              folder: 'notes/$noteId/$category',
              resourceType: CloudinaryResourceType.Auto,
            ),
          )
          .timeout(const Duration(seconds: 45));

      if (response.secureUrl.isEmpty) {
        throw 'Cloudinary không trả về URL hợp lệ.';
      }

      return response.secureUrl;
    } on TimeoutException {
      throw 'Upload Cloudinary quá lâu. Vui lòng thử lại với mạng ổn định hơn.';
    } catch (e) {
      throw 'Lỗi tải lên Cloudinary: $e';
    }
  }

  Future<List<String>> uploadPathList({
    required List<String> paths,
    required String noteId,
    required String category,
  }) async {
    final result = <String>[];
    for (final path in paths) {
      if (isRemoteUrl(path)) {
        result.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) {
        continue;
      }

      final uploaded = await uploadFile(
        file: file,
        noteId: noteId,
        category: category,
      );
      result.add(uploaded);
    }
    return result;
  }

  Future<String?> uploadOptionalPath({
    required String? path,
    required String noteId,
    required String category,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    if (isRemoteUrl(path)) {
      return path;
    }

    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    return uploadFile(file: file, noteId: noteId, category: category);
  }
}
