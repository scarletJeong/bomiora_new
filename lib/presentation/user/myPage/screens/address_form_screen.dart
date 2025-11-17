import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/services/auth_service.dart';

/// 배송지 추가/수정 화면
class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // 수정 시 기존 주소 데이터

  const AddressFormScreen({
    super.key,
    this.address,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // 입력 컨트롤러
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    super.dispose();
  }

  /// 기존 데이터 로드 (수정 모드인 경우)
  void _loadData() {
    if (widget.address != null) {
      _subjectController.text = widget.address!['adSubject'] ?? '';
      _nameController.text = widget.address!['adName'] ?? '';
      _phoneController.text = widget.address!['adHp'] ?? '';
      _zipController.text = '${widget.address!['adZip1'] ?? ''}-${widget.address!['adZip2'] ?? ''}';
      _address1Controller.text = widget.address!['adAddr1'] ?? '';
      _address2Controller.text = '${widget.address!['adAddr2'] ?? ''} ${widget.address!['adAddr3'] ?? ''}'.trim();
      _isDefault = widget.address!['adDefault'] == 1;
    }
  }

  /// 배송지 저장
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      // 우편번호 파싱
      final zipParts = _zipController.text.split('-');
      final zip1 = zipParts.isNotEmpty ? zipParts[0] : '';
      final zip2 = zipParts.length > 1 ? zipParts[1] : '';

      final addressData = {
        'mbId': user.id,
        'adSubject': _subjectController.text.trim(),
        'adDefault': _isDefault ? 1 : 0,
        'adName': _nameController.text.trim(),
        'adTel': _phoneController.text.trim(),
        'adHp': _phoneController.text.trim(),
        'adZip1': zip1,
        'adZip2': zip2,
        'adAddr1': _address1Controller.text.trim(),
        'adAddr2': _address2Controller.text.trim(),
        'adAddr3': '',
        'adJibeon': '',
      };

      Map<String, dynamic> result;
      
      if (widget.address != null) {
        // 수정
        result = await AddressService.updateAddress(
          widget.address!['adId'],
          addressData,
        );
      } else {
        // 추가
        result = await AddressService.addAddress(addressData);
      }

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '배송지가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // 성공 시 true 반환
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '배송지 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ 배송지 저장 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배송지 저장 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(
          widget.address != null ? '배송지 수정' : '배송지 추가',
          style: const TextStyle(
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
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 배송지 이름
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: '배송지 이름',
                hintText: '예) 집, 회사',
                prefixIcon: const Icon(Icons.label_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '배송지 이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 수령인 이름
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '수령인',
                hintText: '이름을 입력하세요',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '수령인을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 연락처
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '연락처',
                hintText: '010-1234-5678',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '연락처를 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 우편번호
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _zipController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: '우편번호',
                      hintText: '우편번호',
                      prefixIcon: const Icon(Icons.mail_outline),
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
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Daum 우편번호 API 연동
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('우편번호 검색 기능은 추후 구현 예정입니다')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3787),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('검색'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 기본 주소
            TextFormField(
              controller: _address1Controller,
              decoration: InputDecoration(
                labelText: '주소',
                hintText: '기본 주소',
                prefixIcon: const Icon(Icons.home_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '주소를 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 상세 주소
            TextFormField(
              controller: _address2Controller,
              decoration: InputDecoration(
                labelText: '상세 주소',
                hintText: '동/호수 입력',
                prefixIcon: const Icon(Icons.apartment_outlined),
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

            // 기본 배송지 설정
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '기본 배송지로 설정',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isDefault,
                    activeColor: const Color(0xFFFF3787),
                    onChanged: (value) {
                      setState(() {
                        _isDefault = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3787),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.address != null ? '수정' : '저장',
                        style: const TextStyle(
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

