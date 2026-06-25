import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../presentation/common/widgets/dropdown_btn.dart';
import '../../presentation/health/health_common/health_responsive_scale.dart';

class ImagePickerUtils {
  static final ImagePicker _picker = ImagePicker();

  /// 식사·교환/환불 등 사진추가 드롭다운 라벨
  static const List<String> photoSourceLabels = [
    '라이브러리에서 선택',
    '사진찍기',
    '파일가져오기',
  ];

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
      return null;
    }
  }

  /// [food_input_widgets] 과 동일 — 흰색 반투명 블러 배경 + 앵커 아래 드롭다운
  static void showPhotoSourceDropdown({
    required BuildContext context,
    required BuildContext anchorContext,
    required void Function(XFile?) onImageSelected,
    double? menuWidth,
  }) {
    DropdownBtn.showMenu(
      context: context,
      anchorContext: anchorContext,
      items: photoSourceLabels,
      menuWidth: menuWidth ?? healthDp(context, 110),
      itemFontSizeBase: 10,
      itemFontFamily: 'Gmarket Sans TTF',
      itemFontWeight: FontWeight.w300,
      blurBackdrop: true,
      blurSigma: 2,
      backdropOpacity: 0.35,
      onSelected: (label) async {
        XFile? image;
        switch (label) {
          case '라이브러리에서 선택':
            image = await pickImageFromGallery();
            break;
          case '사진찍기':
            image = await pickImageFromCamera();
            break;
          case '파일가져오기':
            image = await pickImageFromFile();
            break;
        }
        onImageSelected(image);
      },
    );
  }

  /// 식사 사진: 라이브러리 / 촬영 / 파일 선택 (하단 시트)
  static Future<void> showMealPhotoSourceBottomSheet(
    BuildContext context,
    void Function(XFile?) onImageSelected,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  '라이브러리에서 선택',
                  style: TextStyle(fontFamily: 'Gmarket Sans TTF'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              ListTile(
                title: const Text(
                  '사진찍기',
                  style: TextStyle(fontFamily: 'Gmarket Sans TTF'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              ListTile(
                title: const Text(
                  '파일가져오기',
                  style: TextStyle(fontFamily: 'Gmarket Sans TTF'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'file'),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    XFile? image;
    switch (choice) {
      case 'gallery':
        image = await pickImageFromGallery();
        break;
      case 'camera':
        image = await pickImageFromCamera();
        break;
      case 'file':
        image = await pickImageFromFile();
        break;
    }
    onImageSelected(image);
  }

  /// 파일에서 이미지 선택
  static Future<XFile?> pickImageFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      if (kIsWeb && file.bytes != null) {
        return XFile.fromData(
          file.bytes!,
          name: file.name.isNotEmpty ? file.name : 'image.jpg',
        );
      }
      if (file.path != null && file.path!.isNotEmpty) {
        return XFile(file.path!);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('파일 이미지 선택 오류: $e');
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
        return false;
      }
    }
  }
}
