import 'package:flutter/material.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../utils/find_id_accounts.dart';
import '../widgets/find_account_btn.dart';
import '../widgets/registered_account_ui.dart';

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

      final accounts = parseFindIdAccountEmails(result);

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
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                RegisteredAccountList(
                                  accounts: _accounts,
                                  selectedIndex: _selectedAccountIndex,
                                  onSelect: (index) => setState(
                                    () => _selectedAccountIndex = index,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FindAccountResultActions(
                          onPasswordFind: () {
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
                          onLogin: () {
                            if (_accounts.isEmpty) {
                              Navigator.pushReplacementNamed(context, '/login');
                              return;
                            }
                            final i = _selectedAccountIndex
                                .clamp(0, _accounts.length - 1);
                            Navigator.pushReplacementNamed(
                              context,
                              '/login',
                              arguments: {'prefillEmail': _accounts[i]},
                            );
                          },
                                ),
                              ],
                            ),
                          ),
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
