import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/contact_service.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../widget/contact_inquiry_type_filters.dart';

class ContactFormScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Contact? contact;

  const ContactFormScreen({
    super.key,
    this.onSuccess,
    this.contact,
  });

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kSoftBorder = Color(0x7FD2D2D2);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedType = contactInquiryPrimaryTypes.first;
  String _selectedDetailType =
      contactInquiryDetailMap[contactInquiryPrimaryTypes.first]!.first;
  final List<XFile> _images = [];
  bool _isSubmitting = false;

  bool get _isEditMode => widget.contact != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditMode) return;
    _applyContactToForm(widget.contact!);
  }

  /// 저장 형식: `유형 - 상세 | 사용자제목` 또는 `유형 - 상세`(제목 생략)
  void _applyContactToForm(Contact c) {
    _contentController.text = c.getPlainTextContent();

    var subject = c.wrSubject;
    String customTitle = '';

    final pipeIdx = subject.indexOf(' | ');
    if (pipeIdx != -1) {
      customTitle = subject.substring(pipeIdx + 3).trim();
      subject = subject.substring(0, pipeIdx).trim();
    }

    if (subject.contains(' - ')) {
      final dashIdx = subject.indexOf(' - ');
      final typePart =
          normalizeContactInquiryPrimaryLabel(subject.substring(0, dashIdx).trim());
      final detailPart = subject.substring(dashIdx + 3).trim();
      if (contactInquiryDetailMap.containsKey(typePart)) {
        _selectedType = typePart;
        final details = contactInquiryDetailMap[_selectedType]!;
        _selectedDetailType =
            details.contains(detailPart) ? detailPart : details.first;
        _titleController.text = customTitle;
        return;
      }
    }

    _titleController.text =
        customTitle.isNotEmpty ? customTitle : subject.trim();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 3장까지 첨부할 수 있습니다.')),
      );
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    if (!mounted) return;
    setState(() => _images.add(image));
  }

  Future<void> _submitContact() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final title = _titleController.text.trim();
      final categorySubject = '$_selectedType - $_selectedDetailType';
      final mergedSubject = title.isEmpty ? categorySubject : '$categorySubject | $title';

      final Map<String, dynamic> result = _isEditMode
          ? await ContactService.updateContact(
              wrId: widget.contact!.wrId,
              subject: mergedSubject,
              content: _contentController.text.trim(),
            )
          : await ContactService.createContact(
              subject: mergedSubject,
              content: _contentController.text.trim(),
            );

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? '문의가 수정되었습니다.' : '문의가 등록되었습니다.')),
        );
        widget.onSuccess?.call();
        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '문의 처리에 실패했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문의 처리 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '1:1 문의하기'),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
            children: [
              const SizedBox(height: 20),
              _buildTypeSelectors(),
              const SizedBox(height: 20),
              _buildTitleField(),
              const SizedBox(height: 10),
              _buildContentBox(),
              const SizedBox(height: 20),
              _buildImageBox(),
              const SizedBox(height: 20),
              _buildBottomButtons(),
              const SizedBox(height: 20),
              // const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorder),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: TextFormField(
            controller: _titleController,
            maxLength: 120,
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: '문의 제목을 입력해주세요.',
              hintStyle: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelectors() {
    return ContactInquiryTypeSelectorRow(
      primaryType: _selectedType,
      detailType: _selectedDetailType,
      onChanged: (primary, detail) {
        setState(() {
          _selectedType = primary;
          _selectedDetailType = detail;
        });
      },
    );
  }

  Widget _buildContentBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 207,
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kSoftBorder),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _contentController,
                  maxLength: 3000,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '문의 내용을 입력해주세요.',
                    hintStyle: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w300),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return '문의 내용을 입력해주세요.';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_contentController.text.length}/3,000자',
                  style: const TextStyle(color: _kMuted, fontSize: 10, fontWeight: FontWeight.w300),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: 76,
                height: 76,
                decoration: ShapeDecoration(
                  color: const Color(0x99D2D2D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: Colors.white),
                    SizedBox(height: 4),
                    Text('사진추가하기', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            ..._images.asMap().entries.map((entry) {
              final idx = entry.key;
              final image = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? Image.network(image.path, width: 76, height: 76, fit: BoxFit.cover)
                          : Image.file(File(image.path), width: 76, height: 76, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 3,
                      top: 3,
                      child: InkWell(
                        onTap: () => setState(() => _images.removeAt(idx)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.40),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(color: _kMuted, fontSize: 10, fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 10),
        const Text(
          '*산업안전보건법 제41조, 고객 응대 보호에 따라 욕설 성적 모욕 비하 등\n부적절한 내용은 상담이 제한 되거나 삭제될 수 있습니다.',
          style: TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w300),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 0.5, color: _kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: _kMuted, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            height: 40,
            decoration: ShapeDecoration(
              color: _kPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitContact,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditMode ? '수정' : '등록',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
