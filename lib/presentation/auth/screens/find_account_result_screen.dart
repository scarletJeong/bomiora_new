import 'package:flutter/material.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class FindAccountResultScreen extends StatefulWidget {
  const FindAccountResultScreen({
    super.key,
    required this.certInfo,
  });

  final Map<String, dynamic> certInfo;

  @override
  State<FindAccountResultScreen> createState() =>
      _FindAccountResultScreenState();
}

class _FindAccountResultScreenState
    extends State<FindAccountResultScreen> {
  bool _isLoading = true;
  String? _errorText;
  List<String> _accounts = const [];
  int _selectedAccountIndex = 0;

  String get _certName => (widget.certInfo['name'] ?? '').toString().trim();

  String get _certPhone => (widget.certInfo['phone'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (_certName.isEmpty || _certPhone.isEmpty) {
      _goToNotFound();
      return;
    }

    try {
      final result = await AuthRepository.findId(
        name: _certName,
        phone: _certPhone,
      );

      if (!mounted) return;

      final accounts = (result['accounts'] as List<dynamic>? ?? const [])
          .map((item) => item is Map ? (item['email'] ?? '').toString() : '')
          .where((email) => email.isNotEmpty)
          .toList();

      if (accounts.isEmpty) {
        _goToNotFound();
        return;
      }

      setState(() {
        _accounts = accounts;
        _selectedAccountIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '아이디 조회 중 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  void _goToNotFound() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/find-account-not-found',
      arguments: widget.certInfo,
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorText != null
                  ? _buildErrorView()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '아이디/비밀번호찾기',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: const Text(
                                          '등록된 아이디',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontFamily: 'Gmarket Sans TTF',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        children: List.generate(
                                          _accounts.length,
                                          (index) => Padding(
                                            padding: EdgeInsets.only(
                                              bottom: index == _accounts.length - 1
                                                  ? 0
                                                  : 5,
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => setState(
                                                  () => _selectedAccountIndex = index,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                child: _AccountItem(
                                                  email: _accounts[index],
                                                  selected: index == _selectedAccountIndex,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: () {
                                    if (_accounts.isEmpty) return;
                                    final i = _selectedAccountIndex
                                        .clamp(0, _accounts.length - 1);
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/find-account',
                                      arguments: {
                                        'tab': 'password',
                                        'prefillEmail': _accounts[i],
                                      },
                                    );
                                  },
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
                                    '비밀번호 찾기',
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
                                  onPressed: () => Navigator.pushReplacementNamed(
                                    context,
                                    '/login',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFFFF5A8D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    '로그인하기',
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
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAccounts,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFFF5A8D),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  const _AccountItem({
    required this.email,
    required this.selected,
  });

  final String email;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: selected ? const Color(0x0CFF5C8F) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: selected
                ? const Color(0xFFFF5C8F)
                : const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              email,
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: ShapeDecoration(
              color: selected ? const Color(0xFFFF5C8F) : Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 2,
                  color: selected
                      ? const Color(0xFFFF5C8F)
                      : const Color(0xFFD2D2D2),
                ),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
