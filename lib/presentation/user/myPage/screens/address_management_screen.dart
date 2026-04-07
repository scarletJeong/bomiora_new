import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/models/user/user_model.dart';
import 'address_form_screen.dart';
import '../widgets/my_page_common.dart';

/// 배송지 관리 화면
class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() => _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  UserModel? _currentUser;
  
  // 배송지 목록
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoadingAddresses = false;
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    setState(() {
      _currentUser = user;
    });
    
    if (user != null) {
      _loadAddresses();
    }
  }
  
  Future<void> _loadAddresses() async {
    if (_currentUser == null || _isLoadingAddresses) return;
    
    setState(() {
      _isLoadingAddresses = true;
    });
    
    try {
      final addresses = await AddressService.getAddressList(_currentUser!.id);
      
      if (!mounted) return;
      
      setState(() {
        _addresses = addresses;
        _isLoadingAddresses = false;
      });
    } catch (e) {
      print('❌ 배송지 목록 로드 에러: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildUpdatePayload(Map<String, dynamic> address, {required int isDefault}) {
    return {
      'mbId': _currentUser?.id ?? '',
      'adSubject': address['adSubject'] ?? '',
      'adDefault': isDefault,
      'adName': address['adName'] ?? '',
      'adTel': address['adTel'] ?? address['adHp'] ?? '',
      'adHp': address['adHp'] ?? '',
      'adZip1': address['adZip1'] ?? '',
      'adZip2': address['adZip2'] ?? '',
      'adAddr1': address['adAddr1'] ?? '',
      'adAddr2': address['adAddr2'] ?? '',
      'adAddr3': address['adAddr3'] ?? '',
      'adJibeon': '',
      'adMemo': address['adMemo'] ?? '',
    };
  }

  void _toggleSelection(int id) {
    setState(() {
      _selectedAddressId = _selectedAddressId == id ? null : id;
    });
  }

  Future<void> _goToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressFormScreen(),
      ),
    );
    if (result == true) {
      _loadAddresses();
    }
  }

  Future<void> _goToEditSelected() async {
    final selectedId = _selectedAddressId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정할 배송지를 선택해주세요.')),
      );
      return;
    }
    final selected = _addresses.firstWhere(
      (a) => a['adId'] == selectedId,
      orElse: () => {},
    );
    if (selected.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressFormScreen(address: selected),
      ),
    );
    if (result == true) {
      setState(() {
        _selectedAddressId = null;
      });
      _loadAddresses();
    }
  }

  Future<void> _deleteSelected() async {
    if (_currentUser == null) return;
    final id = _selectedAddressId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제할 배송지를 선택해주세요.')),
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: '배송지 삭제',
      message: '선택한 주소를 삭제하시겠습니까?',
    );
    if (!confirmed) return;

    final deleteResult = await AddressService.deleteAddress(id, _currentUser!.id);

    if (!mounted) return;
    setState(() {
      _selectedAddressId = null;
    });
    await _loadAddresses();
    if (!mounted) return;
    if (deleteResult['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleteResult['message'] ?? '삭제에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setDefaultAddress(Map<String, dynamic> address) async {
    if (_currentUser == null) return;
    final adId = address['adId'] as int?;
    if (adId == null) return;
    final isDefault = address['adDefault'] == 1;
    if (isDefault) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: '기본 주소 설정',
      message: '해당 주소로 기본 주소가 변경됩니다.',
      width: 272,
      showDivider: false,
    );
    if (!confirmed || !mounted) return;

    // UI 즉시 반영 (기존 기본 배송지 해제 + 선택 배송지 기본으로)
    final prevAddresses = List<Map<String, dynamic>>.from(_addresses);
    setState(() {
      _addresses = _addresses
          .map((a) => {
                ...a,
                'adDefault': (a['adId'] == adId) ? 1 : 0,
              })
          .toList();
    });

    await AddressService.updateAddress(
      adId,
      _buildUpdatePayload(address, isDefault: 1),
    );

    // 서버가 기본 배송지 해제까지 처리하지 않는 경우를 대비해 목록 새로고침
    try {
      await _loadAddresses();
    } catch (_) {
      if (!mounted) return;
      setState(() => _addresses = prevAddresses);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '배송지 관리'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: _isLoadingAddresses
            ? const MyPageLoadingIndicator()
            : _currentUser == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '로그인 후 이용 가능합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20, top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_addresses.isNotEmpty) ...[
                      Row(
                        children: const [
                          Text(
                            '나의',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -1.44,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            '배송지',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.76,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '고객님께서 주문시 사용하셨던 배송지 목록입니다.',
                        style: TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (_addresses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 56,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '등록된 배송지가 없습니다',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._addresses.map(
                        (address) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildAddressCard(address),
                        ),
                      ),

                    const SizedBox(height: 14),
                    if (_addresses.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _SmallActionButton(
                                label: '수정',
                                variant: _SmallActionButtonVariant.outlinedPink,
                                enabled: _selectedAddressId != null,
                                onTap: _goToEditSelected,
                              ),
                              const SizedBox(width: 10),
                              _SmallActionButton(
                                label: '삭제',
                                variant: _SmallActionButtonVariant.disabledGray,
                                enabled: _selectedAddressId != null,
                                onTap: _deleteSelected,
                              ),
                            ],
                          ),
                          _SmallActionButton(
                            label: '등록',
                            variant: _SmallActionButtonVariant.filledPink,
                            enabled: true,
                            onTap: _goToRegister,
                          ),
                        ],
                      )
                    else
                      Center(
                        child: _SmallActionButton(
                          label: '등록',
                          variant: _SmallActionButtonVariant.filledPink,
                          enabled: true,
                          onTap: _goToRegister,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 배송지 카드 위젯
  Widget _buildAddressCard(Map<String, dynamic> address) {
    final int? id = address['adId'];
    final String name = address['adSubject'] ?? '';
    final String recipient = address['adName'] ?? '';
    final String phone = address['adHp'] ?? '';
    final String address1 = address['adAddr1'] ?? '';
    final String address2 = address['adAddr2'] ?? '';
    final String address3 = address['adAddr3'] ?? '';
    final String detail = '$address2 $address3'.trim();
    final bool isDefault = address['adDefault'] == 1;
    final bool isSelected = id != null && _selectedAddressId == id;

    // 카드 강조 스타일은 "기본 배송지"가 아니라 "선택(체크)" 상태에 따라 적용
    final bgColor = isSelected ? const Color(0x0CFF5C8F) : Colors.white;
    final borderColor = isSelected ? const Color(0xFFFF5C8F) : const Color(0xFFD2D2D2);

    return InkWell(
      onTap: id == null ? null : () => _toggleSelection(id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: ShapeDecoration(
          color: bgColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1, color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SelectDot(selected: isSelected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '배송지' : name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$recipient $phone'.trim(),
                    style: const TextStyle(
                      color: Color(0xFF898383),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    detail.isEmpty ? address1 : '$address1 $detail',
                    style: const TextStyle(
                      color: Color(0xFF898383),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _setDefaultAddress(address),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isDefault ? Icons.star : Icons.star_border,
                  size: 20,
                  color: isDefault ? Colors.amber : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 16,
        height: 16,
        decoration: ShapeDecoration(
          color: const Color(0xFFFF5C8F),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1.33, color: Color(0xFFFF5C8F)),
            borderRadius: BorderRadius.circular(6666),
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 5.33,
          height: 5.33,
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: OvalBorder(),
          ),
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1.5, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
    );
  }
}

enum _SmallActionButtonVariant { outlinedPink, filledPink, disabledGray }

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.variant,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final _SmallActionButtonVariant variant;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !enabled;

    Color bg;
    Color fg;
    BorderSide? side;

    switch (variant) {
      case _SmallActionButtonVariant.outlinedPink:
        bg = Colors.white;
        fg = const Color(0xFFFF5A8D);
        side = const BorderSide(width: 1, color: Color(0xFFFF5A8D));
        break;
      case _SmallActionButtonVariant.filledPink:
        bg = const Color(0xFFFF5A8D);
        fg = Colors.white;
        side = null;
        break;
      case _SmallActionButtonVariant.disabledGray:
        bg = const Color(0x7FD2D2D2);
        fg = const Color(0xFF898686);
        side = null;
        break;
    }

    // '수정' 버튼은 디자인 고정(비활성화여도 테두리/색 유지) - 탭만 막음
    if (isDisabled && variant == _SmallActionButtonVariant.filledPink) {
      bg = const Color(0x7FD2D2D2);
      fg = const Color(0xFF898686);
      side = null;
    }

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedRectangleBorder(
            side: side ?? BorderSide.none,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

