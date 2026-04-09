import 'package:flutter/material.dart';

import '../../common/widgets/mobile_layout_wrapper.dart';

/// (임시) 결제 WebView 화면.
/// 기존 파일이 삭제되어 빌드가 깨지는 것을 방지하기 위한 최소 구현입니다.
class CheckoutWebViewScreen extends StatelessWidget {
  final String url;
  final String title;

  const CheckoutWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '결제 페이지(임시)',
                  style: TextStyle(
                    fontFamily: 'Gmarket Sans TTF',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('결제 완료(테스트)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

