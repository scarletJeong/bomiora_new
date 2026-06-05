import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/utils/image_picker_utils.dart';
import '../../../../health/health_common/health_responsive_scale.dart';

/// 교환/환불 신청 — 사진 선택·표시 공통 (로컬만, 업로드 API 미연동)
class RefundApplyPhotoUtils {
  RefundApplyPhotoUtils._();

  static const int maxFileBytes = 5 * 1024 * 1024;

  static void pickPhoto(
    BuildContext context,
    BuildContext anchorContext,
    void Function(XFile? file) onPicked,
  ) {
    ImagePickerUtils.showPhotoSourceDropdown(
      context: context,
      anchorContext: anchorContext,
      onImageSelected: (file) async {
        if (file == null) {
          onPicked(null);
          return;
        }
        final error = await _validateFile(file);
        if (!context.mounted) return;
        if (error != null) {
          onPicked(null);
          return;
        }
        onPicked(file);
      },
    );
  }

  static Future<String?> _validateFile(XFile file) async {
    final name = file.name.toLowerCase();
    if (name.isNotEmpty &&
        !name.endsWith('.jpg') &&
        !name.endsWith('.jpeg') &&
        !name.endsWith('.png') &&
        !name.endsWith('.gif')) {
      return 'GIF, JPG, PNG 형식만 등록할 수 있습니다.';
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > maxFileBytes) {
        return '파일당 5MB 이하만 등록할 수 있습니다.';
      }
    } catch (_) {
      return '이미지를 불러올 수 없습니다.';
    }
    return null;
  }

  /// 사진추가하기 회색 카드 — 리뷰 작성 화면과 동일 크기
  static Widget buildAddTile(
    BuildContext context, {
    required void Function(BuildContext anchorContext) onAddTap,
  }) {
    final size = healthDp(context, 76);
    return Builder(
      builder: (anchorContext) {
        return GestureDetector(
          onTap: () => onAddTap(anchorContext),
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0x99D2D2D2),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  AppAssets.addPhotoIcon,
                  width: healthDp(context, 34),
                  height: healthDp(context, 31),
                ),
                SizedBox(height: healthDp(context, 4)),
                Text(
                  '사진추가하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget buildThumb(
    BuildContext context,
    XFile file,
    VoidCallback onRemove,
  ) {
    final size = healthDp(context, 76);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return SizedBox(
                width: size,
                height: size,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
              child: Image.memory(
                snap.data!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
        Positioned(
          top: -healthDp(context, 4),
          right: -healthDp(context, 4),
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: EdgeInsets.all(healthDp(context, 2)),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: healthDp(context, 14), color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// 썸네일 + 추가 타일을 왼쪽 정렬 [Wrap]
  static Widget buildPhotoRow({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: healthDp(context, 5),
      runSpacing: healthDp(context, 5),
      children: children,
    );
  }
}
