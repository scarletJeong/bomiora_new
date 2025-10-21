import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerUtils {
  static final ImagePicker _picker = ImagePicker();

  /// 이미지 선택 옵션을 보여주는 다이얼로그 (콜백 방식)
  static Future<void> showImageSourceDialog(
    BuildContext context,
    Function(XFile?) onImageSelected,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('이미지 선택'),
          content: const Text('이미지를 어떻게 가져오시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                onImageSelected(image);
              },
              child: const Text('카메라'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                onImageSelected(image);
              },
              child: const Text('갤러리'),
            ),
          ],
        );
      },
    );
  }

  /// 카메라에서 이미지 선택
  static Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } catch (e) {
      print('카메라 이미지 선택 오류: $e');
      return null;
    }
  }

  /// 갤러리에서 이미지 선택
  static Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (e) {
      print('갤러리 이미지 선택 오류: $e');
      return null;
    }
  }

  /// 이미지 파일을 File 객체로 변환
  static File? convertToFile(XFile? xFile) {
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// 이미지 파일 존재 여부 확인
  static bool isImageFileExists(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    if (kIsWeb) {
      // 웹에서는 URL이 유효한지 간단히 체크
      return imagePath.startsWith('http') || imagePath.startsWith('blob:');
    } else {
      return File(imagePath).existsSync();
    }
  }

  /// 이미지 파일 삭제
  static Future<bool> deleteImageFile(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    if (kIsWeb) {
      // 웹에서는 파일 삭제가 제한적이므로 항상 true 반환
      return true;
    } else {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
        return false;
      } catch (e) {
        print('이미지 파일 삭제 오류: $e');
        return false;
      }
    }
  }
}
