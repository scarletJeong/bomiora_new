import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_footer.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/address_service.dart';
import '../../../../data/models/user/user_model.dart';
import 'address_form_screen.dart';

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

  Future<void> _deleteAddress(int id) async {
    if (_currentUser == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배송지 삭제'),
        content: const Text('이 배송지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final result = await AddressService.deleteAddress(
                  id,
                  _currentUser!.id,
                );
                
                if (!mounted) return;
                
                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? '배송지가 삭제되었습니다.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // 배송지 목록 새로고침
                  _loadAddresses();
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
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefaultAddress(int id) async {
    if (_currentUser == null) return;

    final result = await AddressService.setDefaultAddress(id, _currentUser!.id);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '기본 배송지로 설정되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAddresses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '기본 배송지 설정에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text('배송지 관리'),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      child: _isLoadingAddresses
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF3787),
              ),
            )
          : SingleChildScrollView(
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
                  
                  const SizedBox(height: 300),
                  const AppFooter(),
                ],
              ),
            ),
    );
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
                  if (isDefault)
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isDefault) const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.grey[600],
                    onPressed: () async {
                      // 배송지 수정 화면으로 이동
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressFormScreen(
                            address: {
                              'adId': id,
                              'adSubject': name,
                              'adName': recipient,
                              'adHp': phone,
                              'adAddr1': address,
                              'adAddr2': addressDetail,
                              'adDefault': isDefault ? 1 : 0,
                            },
                          ),
                        ),
                      );
                      
                      // 배송지가 수정되면 목록 새로고침
                      if (result == true) {
                        _loadAddresses();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    onPressed: () => _deleteAddress(id!),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recipient,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
          if (addressDetail.isNotEmpty)
            Text(
              addressDetail,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          if (!isDefault && id != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _setDefaultAddress(id),
                child: const Text('기본배송지로 설정'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
