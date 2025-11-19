import 'package:flutter/material.dart';
import '../../../data/services/contact_service.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';

class ContactFormScreen extends StatefulWidget {
  final VoidCallback? onSuccess; // 등록/수정 성공 시 호출할 콜백
  final Contact? contact; // 수정 모드일 때 기존 문의 데이터
  
  const ContactFormScreen({
    super.key, 
    this.onSuccess,
    this.contact, // null이면 작성 모드, 있으면 수정 모드
  });

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isEditMode => widget.contact != null;

  @override
  void initState() {
    super.initState();
    // 수정 모드일 때 기존 데이터로 초기화
    if (_isEditMode) {
      _subjectController.text = widget.contact!.wrSubject;
      _contentController.text = widget.contact!.getPlainTextContent();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (_isEditMode) {
        // 수정 모드
        result = await ContactService.updateContact(
          wrId: widget.contact!.wrId,
          subject: _subjectController.text.trim(),
          content: _contentController.text.trim(),
        );
      } else {
        // 작성 모드
        result = await ContactService.createContact(
          subject: _subjectController.text.trim(),
          content: _contentController.text.trim(),
        );
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode 
                  ? '문의가 수정되었습니다.'
                  : '문의가 등록되었습니다.\n문의하신 내용은 빠른 시일 내에 답변드리겠습니다.\n답변은 "내 문의내역"에서 확인하실 수 있습니다.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: _isEditMode ? 2 : 4),
            ),
          );
          // 수정 모드일 때는 이전 페이지로 돌아감
          if (_isEditMode) {
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            }
            Navigator.pop(context, true);
          } else {
            // 작성 모드일 때는 콜백이 있으면 콜백 호출 (탭 변경), 없으면 이전 페이지로 돌아감
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            } else {
              Navigator.pop(context, true);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? (_isEditMode ? '문의 수정에 실패했습니다.' : '문의 등록에 실패했습니다.'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode 
                ? '문의 수정 중 오류가 발생했습니다: $e'
                : '문의 등록 중 오류가 발생했습니다: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 수정 모드이거나 onSuccess가 null이면 독립적인 화면으로 표시 (AppBar 포함)
    // onSuccess가 있으면 TabBarView 안에서 사용되는 것으로 간주
    final isStandalone = _isEditMode || widget.onSuccess == null;
    
    if (isStandalone) {
      return MobileAppLayoutWrapper(
        appBar: AppBar(
          title: Text(
            _isEditMode ? '문의 수정' : '상품 문의하기',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        child: Material(
          color: Colors.transparent,
          child: _buildForm(),
        ),
      );
    }
    
    // TabBarView 안에서 사용될 때는 Material만 감싸기
    return Material(
      color: Colors.transparent,
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 컨텐츠에 padding 적용
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // 제목 입력
              Text(
                '제목',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: '문의 제목을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  if (value.trim().length < 2) {
                    return '제목은 2자 이상 입력해주세요';
                  }
                  return null;
                },
                maxLength: 100,
              ),
              const SizedBox(height: 24),
              
              // 내용 입력
              Text(
                '내용',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: '문의 내용을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '내용을 입력해주세요';
                  }
                  if (value.trim().length < 10) {
                    return '내용은 10자 이상 입력해주세요';
                  }
                  return null;
                },
                maxLength: 2000,
              ),
              const SizedBox(height: 32),
              
              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3787),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isEditMode ? '수정' : '등록',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
                ],
              ),
            ),
            
            const SizedBox(height: 300),
            
            // Footer  
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}

