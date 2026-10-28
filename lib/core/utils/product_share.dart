import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../presentation/common/widgets/app_toast_overlay.dart';
import '../navigation/app_navigator_key.dart';
import 'inf_code_tracker.dart';

/// 상품 공유: 휴대폰 공유 시트(카카오톡, 메시지 등)로 제목·링크를 넘긴다.
/// 링크는 현재 웹 호스트 기준 path 라우트(`/product/:id`)를 사용합니다.
class ProductShare {
  ProductShare._();

  static const String _productionWebOrigin = 'https://bomiora.net';

  /// 공유·복사용 상품 URL (`http://localhost:55223/product/...` 또는 `https://bomiora.net/product/...`)
  static String buildPublicProductUrl(
    String itId, {
    String? productKind,
    String? infCode,
  }) {
    final id = itId.trim();
    final kind = (productKind ?? '').trim().toLowerCase();
    final path = kind == 'general' ? 'product-general' : 'product';

    final query = <String, String>{};
    final code = (infCode ?? InfCodeTracker.current)?.trim();
    if (code != null && code.isNotEmpty) {
      query['infcode'] = code;
    }

    final routeUri = Uri(
      path: '/$path/$id',
      queryParameters: query.isEmpty ? null : query,
    );

    if (kIsWeb) {
      return '${Uri.base.origin}${routeUri.toString()}';
    }
    return '$_productionWebOrigin${routeUri.toString()}';
  }

  /// 시스템 공유 시트를 연다. 시트를 쓸 수 없을 때만 링크를 복사한다.
  ///
  /// 반환값: 시트를 열었으면 true, 복사로 대체했으면 false, 사용자가 닫았으면 null.
  static Future<bool?> shareProduct({
    required BuildContext anchorContext,
    required String itId,
    required String productName,
    String? productKind,
    String? infCode,
  }) async {
    final url = buildPublicProductUrl(
      itId,
      productKind: productKind,
      infCode: infCode,
    );
    final name = productName.trim().isNotEmpty ? productName.trim() : '보미오라 상품';
    final text = '$name\n$url';

    final box = anchorContext.findRenderObject() as RenderBox?;
    final Rect? origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: name,
          subject: name,
          sharePositionOrigin: origin,
          mailToFallbackEnabled: false,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return null;
      return true;
    } catch (e) {
      if (_shouldFallbackToClipboard(e)) {
        await Clipboard.setData(ClipboardData(text: url));
        return false;
      }
      rethrow;
    }
  }

  /// 공유 실행 후 사용자 피드백(토스트)까지 처리합니다.
  static Future<void> shareProductWithFeedback({
    required BuildContext context,
    required BuildContext anchorContext,
    required String itId,
    required String productName,
    String? productKind,
    String? infCode,
  }) async {
    try {
      final shared = await shareProduct(
        anchorContext: anchorContext,
        itId: itId,
        productName: productName,
        productKind: productKind,
        infCode: infCode,
      );
      if (shared == false) {
        _showFeedback(context, '이 기기에서는 공유 창을 열 수 없어 링크를 복사했습니다.');
      }
    } catch (_) {
      _showFeedback(context, '공유에 실패했습니다.');
    }
  }

  static void _showFeedback(BuildContext context, String message) {
    final ctx = context.mounted ? context : appNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    AppToastOverlay.show(ctx, message);
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
    return s.contains('missingplugin') ||
        s.contains('missing plugin') ||
        s.contains('canshare') ||
        s.contains('share api is not supported') ||
        s.contains('navigator.share');
  }
}
