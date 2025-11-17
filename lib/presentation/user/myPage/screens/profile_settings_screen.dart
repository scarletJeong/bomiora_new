import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/models/user/user_model.dart';
import 'address_form_screen.dart';

/// 프로필 설정 화면 (개인정보 수정, 비밀번호 변경, 배송지 관리)
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _currentUser;
  
  // 회원정보 입력 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // 배송지 목록
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoadingAddresses = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrentUser();
  }
  
  void _onTabChanged() {
    // 배송지 탭으로 전환할 때 배송지 목록 로드
    if (_tabController.index == 1 && !_isLoadingAddresses) {
      _loadAddresses();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    // 콘솔에 현재 사용자 정보 출력
    print('📱 [프로필 설정] 현재 사용자 정보:');
    print('   - ID: ${user?.id}');
    print('   - 이메일: ${user?.email}');
    print('   - 이름: ${user?.name}');
    print('   - 닉네임: ${user?.nickname}');
    print('   - 전화번호: ${user?.phone}');

    setState(() {
      _currentUser = user;
      // 컨트롤러에 초기값 설정
      _nameController.text = user?.name ?? '';
      _nicknameController.text = user?.nickname ?? '';
      _phoneController.text = user?.phone ?? '';
    });
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
  
  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    
    try {
      final result = await AuthService.updateProfile(
        mbId: _currentUser!.id,
        name: _nameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '프로필이 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 사용자 정보 새로고침
        await _loadCurrentUser();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '프로필 수정에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ 프로필 저장 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 수정 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '프로필 설정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF4081),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF4081),
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: '회원정보'),
            Tab(text: '배송지 관리'),
          ],
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalInfoTab(),
          _buildAddressTab(),
        ],
      ),
    );
  }

  /// 회원정보 탭
  Widget _buildPersonalInfoTab() {
    // 사용자 정보가 로드되지 않았으면 로딩 표시
    if (_currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF3787),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // 프로필 사진
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFFF3787).withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Color(0xFFFF3787),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3787),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: 프로필 사진 변경 기능 구현
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 사진 변경 기능은 추후 구현 예정입니다')),
                );
              },
              child: const Text('프로필 사진 변경'),
            ),
          ),
          const SizedBox(height: 32),

          // 이메일 (수정 불가)
          _buildTextField(
            label: '이메일',
            initialValue: _currentUser!.email,
            hint: '이메일',
            icon: Icons.email_outlined,
            enabled: false,
          ),
          const SizedBox(height: 16),

          // 이름
          _buildTextFieldWithController(
            label: '이름',
            controller: _nameController,
            hint: '이름을 입력하세요',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          // 닉네임
          _buildTextFieldWithController(
            label: '닉네임',
            controller: _nicknameController,
            hint: '닉네임을 입력하세요',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),

          // 비밀번호
          _buildPasswordField(
            label: '비밀번호',
            hint: '비밀번호 변경',
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 16),

          // 휴대폰번호
          _buildTextFieldWithController(
            label: '휴대폰번호',
            controller: _phoneController,
            hint: '휴대폰번호를 입력하세요',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // 환불계좌
          _buildTextField(
            label: '환불계좌',
            initialValue: '',
            hint: '환불받을 계좌번호를 입력하세요',
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 32),

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3787),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '수정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),

          // 회원탈퇴 버튼 (오른쪽 정렬)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // 회원탈퇴 화면으로 이동
                Navigator.pushNamed(context, '/cancel-member');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                '회원탈퇴',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 배송지 관리 탭
  Widget _buildAddressTab() {
    if (_isLoadingAddresses) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF3787),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(), // 왼쪽 공간 확보용
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  // 배송지 추가 화면으로 이동
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressFormScreen(),
                    ),
                  );
                  
                  // 배송지가 추가되면 목록 새로고침
                  if (result == true) {
                    _loadAddresses();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('추가'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF4081),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 배송지 목록 (실제 데이터)
          if (_addresses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '등록된 배송지가 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_addresses.map((address) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAddressCard(
                id: address['adId'],
                name: address['adSubject'] ?? '',
                recipient: address['adName'] ?? '',
                phone: address['adHp'] ?? '',
                address: address['adAddr1'] ?? '',
                addressDetail: '${address['adAddr2'] ?? ''} ${address['adAddr3'] ?? ''}'.trim(),
                isDefault: address['adDefault'] == 1,
              ),
            ))),
        ],
      ),
    );
  }

  /// 텍스트 필드 위젯
  Widget _buildTextField({
    required String label,
    required String initialValue,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF4081)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
    );
  }

  /// Controller를 사용하는 텍스트 필드 위젯
  Widget _buildTextFieldWithController({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF4081)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
    );
  }

  /// 비밀번호 필드 위젯 (클릭하면 비밀번호 변경 화면으로)
  Widget _buildPasswordField({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        // 비밀번호 변경 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _PasswordChangeScreen(),
          ),
        );
      },
      child: IgnorePointer(
        child: TextFormField(
          initialValue: '••••••••',
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF4081)),
            ),
          ),
        ),
      ),
    );
  }

  /// 배송지 삭제
  Future<void> _deleteAddress(int id) async {
    if (_currentUser == null) return;
    
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배송지 삭제'),
        content: const Text('이 배송지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final result = await AddressService.deleteAddress(id, _currentUser!.id);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '배송지가 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 배송지 목록 새로고침
        await _loadAddresses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '배송지 삭제에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ 배송지 삭제 에러: $e');
    }
  }

  /// 배송지 카드 위젯
  Widget _buildAddressCard({
    int? id,
    required String name,
    required String recipient,
    required String phone,
    required String address,
    required String addressDetail,
    bool isDefault = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFFFF4081) : Colors.grey[300]!,
          width: isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4081),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '기본',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: id != null
                        ? () async {
                            // 배송지 수정 화면으로 이동
                            final addressData = _addresses.firstWhere(
                              (addr) => addr['adId'] == id,
                              orElse: () => {},
                            );
                            
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddressFormScreen(address: addressData),
                              ),
                            );
                            
                            // 배송지가 수정되면 목록 새로고침
                            if (result == true) {
                              _loadAddresses();
                            }
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: id != null ? () => _deleteAddress(id) : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recipient,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$address\n$addressDetail',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 비밀번호 변경 화면
class _PasswordChangeScreen extends StatefulWidget {
  const _PasswordChangeScreen();

  @override
  State<_PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<_PasswordChangeScreen> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscureCurrentPassword = true;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '비밀번호 변경',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '비밀번호 변경',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 현재 비밀번호
            TextFormField(
              controller: currentPasswordController,
              obscureText: obscureCurrentPassword,
              decoration: InputDecoration(
                labelText: '현재 비밀번호',
                hintText: '현재 비밀번호를 입력하세요',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureCurrentPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureCurrentPassword = !obscureCurrentPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 새 비밀번호
            TextFormField(
              controller: newPasswordController,
              obscureText: obscureNewPassword,
              decoration: InputDecoration(
                labelText: '새 비밀번호',
                hintText: '새 비밀번호를 입력하세요',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureNewPassword = !obscureNewPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 새 비밀번호 확인
            TextFormField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: '새 비밀번호 확인',
                hintText: '새 비밀번호를 다시 입력하세요',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 비밀번호 안내 텍스트
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '비밀번호 규칙',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 8자 이상 입력하세요\n• 영문, 숫자, 특수문자를 포함하세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 변경 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 비밀번호 변경 API 호출
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호 변경 기능은 추후 구현 예정입니다')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3787),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '비밀번호 변경',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

