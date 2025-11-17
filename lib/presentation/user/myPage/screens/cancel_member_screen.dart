import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

/// 회원탈퇴 화면
class CancelMemberScreen extends StatefulWidget {
  const CancelMemberScreen({super.key});

  @override
  State<CancelMemberScreen> createState() => _CancelMemberScreenState();
}

class _CancelMemberScreenState extends State<CancelMemberScreen> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _reasonOptions = [
    '서비스가 만족스럽지 않아서',
    '사용 빈도가 낮아서',
    '개인정보 보호를 위해',
    '다른 서비스를 이용하기 위해',
    '기타',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showFinalConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '정말로 탈퇴하시겠습니까?\n\n'
          '탈퇴 시 모든 회원정보와 주문내역이 삭제되며,\n'
          '삭제된 정보는 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 탈퇴 사유 화면 닫기
              // TODO: 회원탈퇴 API 호출
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('회원탈퇴 기능은 추후 구현 예정입니다'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text(
              '탈퇴',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '회원탈퇴',
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
              '탈퇴 사유를 선택해주세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 탈퇴 사유 선택
            ..._reasonOptions.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              activeColor: const Color(0xFFFF3787),
              onChanged: (value) {
                setState(() {
                  _selectedReason = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            )),

            const SizedBox(height: 24),

            // 기타 사유 입력 (기타 선택 시)
            if (_selectedReason == '기타') ...[
              const Text(
                '상세 사유를 입력해주세요',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '탈퇴 사유를 자세히 입력해주세요',
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
            ],

            const SizedBox(height: 32),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason == null
                    ? null
                    : () {
                        // 기타 선택 시 상세 사유 확인
                        if (_selectedReason == '기타' && _reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('탈퇴 사유를 입력해주세요')),
                          );
                          return;
                        }
                        // 최종 확인 다이얼로그 표시
                        _showFinalConfirmDialog();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3787),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  '확인',
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

