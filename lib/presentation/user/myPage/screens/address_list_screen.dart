import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/app_alert_dialog.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/models/user/user_model.dart';
import 'address_form_screen.dart';

/// 배송지 관리 화면
class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  static const double _confirmDialogWidth = 272;

  UserModel? _currentUser;
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoadingAddresses = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  bool _isFormSuccess(dynamic result) {
    if (result == true) return true;
    if (result is Map && result['ok'] == true) return true;
    return false;
  }

  void _handleFormResult(dynamic result) {
    if (!_isFormSuccess(result)) return;
    _loadAddresses();
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

      addresses.sort((a, b) {
        final ad = _isDefaultAddress(a) ? 0 : 1;
        final bd = _isDefaultAddress(b) ? 0 : 1;
        if (ad != bd) return ad.compareTo(bd);
        final aid = (a['adId'] as int?) ?? 0;
        final bid = (b['adId'] as int?) ?? 0;
        return bid.compareTo(aid);
      });

      setState(() {
        _addresses = addresses;
        _isLoadingAddresses = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  Future<void> _goToRegister() async {
    if (_addresses.length >= 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '배송지는 최대 10개까지 등록할 수 있습니다.',
            style: TextStyle(
              fontFamily: 'Gmarket Sans TTF',
              fontSize: healthSp(context, 14),
              fontWeight: FontWeight.w500,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressFormScreen(),
      ),
    );
    if (!mounted) return;
    _handleFormResult(result);
  }

  Future<void> _goToEdit(Map<String, dynamic> address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressFormScreen(address: address),
      ),
    );
    if (!mounted) return;
    _handleFormResult(result);
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    if (_currentUser == null) return;
    final id = address['adId'] as int?;
    if (id == null) return;

    final isDefault = _isDefaultAddress(address);
    if (isDefault) {
      await AppAlertDialog.show(
        context,
        title: '기본 배송지 설정',
        message: '다른 배송지를 기본 배송지로 \n설정 후 삭제해주세요.',
        width: _confirmDialogWidth,
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: '배송지 삭제',
      message: '선택한 주소를 삭제하시겠습니까?',
      width: _confirmDialogWidth,
    );
    if (!confirmed) return;

    final result = await AddressService.deleteAddress(id, _currentUser!.id);
    if (!mounted) return;
    await _loadAddresses();
    if (!mounted) return;
    if (result['success'] == true) {
      AppToastOverlay.show(context, '배송지가 삭제됐어요.');
    }
  }

  Widget _buildAddAddressButton() {
    return InkWell(
      onTap: _goToRegister,
      borderRadius: BorderRadius.circular(healthDp(context, 7)),
      child: Container(
        width: double.infinity,
        height: healthDp(context, 39),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0x00FF5A8D),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '+ 배송지 신규입력',
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isDefaultAddress(Map<String, dynamic> address) {
    final v = address['adDefault'];
    return v == 1 || v == '1' || v == true;
  }

  Widget _buildCardActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 8)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 8),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0x7FD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 8)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    return Theme(
      data: gmarketTheme,
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '배송지 관리',
          titleFontSize: healthSp(context, 18),
          leadingIconSize: healthDp(context, 24),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: _isLoadingAddresses
              ? Center(
                  child: SizedBox(
                    width: healthDp(context, 36),
                    height: healthDp(context, 36),
                    child: const CircularProgressIndicator(
                      color: Color(0xFFFF3787),
                    ),
                  ),
                )
              : _currentUser == null
                  ? CenteredEmptyState(
                      iconWidget: CenteredEmptyState.assetIcon(
                        context,
                        AppAssets.emptyAddressIcon,
                      ),
                      message: '로그인 후 이용 가능합니다.',
                      trailing: CenteredEmptyState.loginButtonTrailing(
                        context,
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/login');
                          if (!mounted) return;
                          await _loadCurrentUser();
                        },
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final contentPadding = EdgeInsets.only(
                          left: healthDp(context, 27),
                          right: healthDp(context, 27),
                          bottom: healthDp(context, 20),
                          top: healthDp(context, 20),
                        );

                        if (_addresses.isEmpty) {
                          return Padding(
                            padding: contentPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAddAddressButton(),
                                SizedBox(height: healthDp(context, 16)),
                                Expanded(
                                  child: Center(
                                    child: CenteredEmptyState(
                                      iconWidget: CenteredEmptyState.assetIcon(
                                        context,
                                        AppAssets.emptyAddressIcon,
                                      ),
                                      message: '등록된 배송지가 없습니다',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          padding: contentPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAddAddressButton(),
                              SizedBox(height: healthDp(context, 16)),
                              ..._addresses.asMap().entries.map((entry) {
                                final isLast =
                                    entry.key == _addresses.length - 1;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: isLast ? 0 : healthDp(context, 10),
                                  ),
                                  child: _buildAddressCard(entry.value),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final String subject = (address['adSubject'] ?? '').toString().trim();
    final String recipient = (address['adName'] ?? '').toString().trim();
    final String phone = (address['adHp'] ?? '').toString().trim();
    final String address1 = (address['adAddr1'] ?? '').toString().trim();
    final String address2 = (address['adAddr2'] ?? '').toString().trim();
    final String address3 = (address['adAddr3'] ?? '').toString().trim();
    final String detail = '$address2 $address3'.trim();
    final bool isDefault = _isDefaultAddress(address);

    final titleName = recipient.isEmpty ? '수령인' : recipient;
    final titleText =
        subject.isEmpty ? titleName : '$titleName ($subject)';
    final fullAddress = detail.isEmpty ? address1 : '$address1 $detail';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: isDefault ? const Color(0x0CFF5C8F) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: isDefault
                ? const Color(0xFFFF5C8F)
                : const Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isDefault) ...[
                SizedBox(width: healthDp(context, 4)),
                Container(
                  padding: EdgeInsets.all(healthDp(context, 5)),
                  decoration: ShapeDecoration(
                    color: const Color(0x0CFF5A8D),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 50)),
                    ),
                  ),
                  child: Text(
                    '기본배송지',
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: healthDp(context, 10)),
          if (phone.isNotEmpty) ...[
            Text(
              phone,
              style: TextStyle(
                color: const Color(0xFF898383),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: healthDp(context, 5)),
          ],
          Text(
            fullAddress.isEmpty ? '-' : fullAddress,
            style: TextStyle(
              color: const Color(0xFF898383),
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
          SizedBox(height: healthDp(context, 10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCardActionButton(
                label: '삭제',
                onTap: () => _deleteAddress(address),
              ),
              SizedBox(width: healthDp(context, 5)),
              _buildCardActionButton(
                label: '수정',
                onTap: () => _goToEdit(address),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
