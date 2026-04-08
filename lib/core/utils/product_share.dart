import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 상품 공유: 시스템 공유 시트(카톡 등)로 제목·링크 전달.
/// 링크는 앱 미설치 사용자도 브라우저로 열 수 있는 쇼핑몰 웹 상품 페이지를 사용합니다.
class ProductShare {
  ProductShare._();

  /// `orderform.php` 등과 동일 호스트. 실제 상품 경로가 다르면 이 값만 수정하면 됩니다.
  static const String _publicShopItemBase = 'https://bomiora.kr/shop/item.php';

  static String buildPublicProductUrl(String itId) {
    return '$_publicShopItemBase?it_id=${Uri.encodeQueryComponent(itId)}';
  }

  /// [true]: 공유 시트(또는 Web Share) 호출까지 완료.
  /// [false]: 플러그인 미등록 등으로 공유 불가 → 클립보드에만 복사함(스낵바는 호출 쪽에서 처리).
  static Future<bool> shareProduct({
    required BuildContext anchorContext,
    required String itId,
    required String productName,
  }) async {
    final url = buildPublicProductUrl(itId);
    final text = productName.isNotEmpty ? '$productName\n$url' : url;

    final box = anchorContext.findRenderObject() as RenderBox?;
    final Rect? origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: productName.isNotEmpty ? productName : '보미오라 상품',
          subject: productName.isNotEmpty ? productName : '보미오라 상품',
          sharePositionOrigin: origin,
        ),
      );
      return true;
    } catch (e) {
      if (_shouldFallbackToClipboard(e)) {
        await Clipboard.setData(ClipboardData(text: text));
        return false;
      }
      rethrow;
    }
  }

  static bool _shouldFallbackToClipboard(Object error) {
    if (error is MissingPluginException) return true;
    if (error is PlatformException) {
      final blob =
          '${error.code} ${error.message ?? ''} ${error.details ?? ''}'
              .toLowerCase();
      return blob.contains('missingplugin') || blob.contains('missing plugin');
    }
    final s = error.toString().toLowerCase();
    return s.contains('missingplugin') || s.contains('missing plugin');
  }
}
