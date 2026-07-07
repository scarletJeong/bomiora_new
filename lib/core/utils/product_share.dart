import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../navigation/app_navigator_key.dart';
import 'inf_code_tracker.dart';

/// 상품 공유: 시스템 공유 시트(카톡 등)로 제목·링크 전달.
/// 링크는 현재 웹 호스트 기준 Flutter 해시 라우트(`/#/product/:id`)를 사용합니다.
class ProductShare {
  ProductShare._();

  static const String _productionWebOrigin = 'https://bomiora.net';

  /// 공유·복사용 상품 URL (`http://localhost:55223/#/product/...` 또는 `https://bomiora.net/#/product/...`)
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
    final hashPath = routeUri.toString();

    if (kIsWeb) {
      return '${Uri.base.origin}/#$hashPath';
    }
    return '$_productionWebOrigin/#$hashPath';
  }

  static Future<bool> shareProduct({
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

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: url));
      return false;
    }

    final box = anchorContext.findRenderObject() as RenderBox?;
    final Rect? origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: url,
          title: productName.isNotEmpty ? productName : '보미오라 상품',
          subject: productName.isNotEmpty ? productName : '보미오라 상품',
          sharePositionOrigin: origin,
        ),
      );
      return true;
    } catch (e) {
      if (_shouldFallbackToClipboard(e)) {
        await Clipboard.setData(ClipboardData(text: url));
        return false;
      }
      rethrow;
    }
  }

  /// 공유 실행 후 사용자 피드백(스낵바)까지 처리합니다.
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
      _showFeedbackSnackBar(
        shared ? '공유하기를 실행했습니다.' : '링크가 클립보드에 복사되었습니다.',
      );
    } catch (_) {
      _showFeedbackSnackBar('공유에 실패했습니다.');
    }
  }

  static void _showFeedbackSnackBar(String message) {
    final rootContext = appNavigatorKey.currentContext;
    if (rootContext == null || !rootContext.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(rootContext);
    if (messenger == null) return;

    final screenW = MediaQuery.sizeOf(rootContext).width;
    final barWidth =
        (screenW > 650 ? 618.0 : screenW - 32).clamp(200.0, screenW);
    final hMargin = ((screenW - barWidth) / 2).clamp(16.0, double.infinity);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.35,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(hMargin, 0, hMargin, 88),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        duration: const Duration(seconds: 2),
      ),
    );
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
