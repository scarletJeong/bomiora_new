import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

/// 아이디/비밀번호 찾기 공통 — 일치 회원 없음
/// 인자: `retryTab` `'password'` | `'id'` (생략 시 `'id'`), 하위 호환으로 `mode: 'password'` 도 동일 처리
class FindAccountNotFoundScreen extends StatelessWidget {
  const FindAccountNotFoundScreen({
    super.key,
    this.findAccountInfo,
  });

  final Map<String, dynamic>? findAccountInfo;

  bool get _openPasswordTabOnRetry {
    final info = findAccountInfo;
    if (info == null) return false;
    final retry = (info['retryTab'] ?? '').toString().toLowerCase();
    if (retry == 'password') return true;
    return (info['mode'] ?? '').toString() == 'password';
  }

  void _onRetry(BuildContext context) {
    Navigator.pushReplacementNamed(
      context,
      '/find-account',
      arguments: _openPasswordTabOnRetry ? {'tab': 'password'} : null,
    );
  }

  void _onSignup(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/kcp-cert',
      arguments: const {'flow': 'signup'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(title: '아이디/비밀번호찾기'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Image.asset(
                    AppAssets.loginFail,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: ShapeDecoration(
                          color: const Color(0x19FF5C8F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        child: const Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: Color(0xFFFF5C8F),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  child: const Column(
                    children: [
                      Text(
                        '일치하는 정보가 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '입력하신 정보로 가입된 아이디를\n찾을 수 없습니다. 다시 확인해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => _onRetry(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              width: 0.5,
                              color: Color(0xFFD2D2D2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '다시 찾기',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF898686),
                              fontSize: 16,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => _onSignup(context),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFFF5A8D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '회원가입 하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
