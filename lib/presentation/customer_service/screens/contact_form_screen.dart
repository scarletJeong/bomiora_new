import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/contact_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widget/contact_inquiry_type_filters.dart';

class ContactFormScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Contact? contact;
  final int? parentWrId; // 추가질문: 연결할 원글(또는 스레드)의 wr_id

  const ContactFormScreen({
    super.key,
    this.onSuccess,
    this.contact,
    this.parentWrId,
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
              parentWrId: widget.parentWrId,
            );

      if (!mounted) return;
      if (result['success'] == true) {
        widget.onSuccess?.call();
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '1:1 문의',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.only(
                  left: healthDp(context, 27),
                  right: healthDp(context, 27),
                  bottom: healthDp(context, 20),
                ),
                children: [
                  SizedBox(height: healthDp(context, 16)),
                  _buildTypeSelectors(),
                  SizedBox(height: healthDp(context, 16)),
                  _buildTitleField(),
                  SizedBox(height: healthDp(context, 10)),
                  _buildContentBox(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildImageBox(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildBottomButtons(),
                  SizedBox(height: healthDp(context, 20)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: healthDp(context, 8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  width: healthDp(context, 1), color: _kBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: TextFormField(
            controller: _titleController,
            maxLength: 120,
            style: TextStyle(
              fontSize: healthSp(context, 10), // 확인해봐
              fontWeight: FontWeight.w500,
              color: _kInk,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: '제목을 입력해주세요.',
              hintStyle: TextStyle(
                color: _kMuted,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w300,
              ),
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
          height: healthDp(context, 207),
          padding: EdgeInsets.all(healthDp(context, 20)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  width: healthDp(context, 1), color: _kSoftBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 7)),
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
                  style: TextStyle(
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: _kInk,
                  ),
                  decoration: InputDecoration(
                    hintText: '문의 내용을 입력해주세요.',
                    hintStyle: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w300,
                    ),
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
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageBox() {
    final thumb = healthDp(context, 76);
    final r10 = healthDp(context, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: thumb,
                height: thumb,
                decoration: ShapeDecoration(
                  color: const Color(0x99D2D2D2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r10)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white,
                      size: healthDp(context, 24),
                    ),
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      '사진추가하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 10),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 5)),
            ..._images.asMap().entries.map((entry) {
              final idx = entry.key;
              final image = entry.value;
              return Padding(
                padding: EdgeInsets.only(right: healthDp(context, 5)),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(r10),
                      child: kIsWeb
                          ? Image.network(image.path,
                              width: thumb, height: thumb, fit: BoxFit.cover)
                          : Image.file(File(image.path),
                              width: thumb, height: thumb, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: healthDp(context, 3),
                      top: healthDp(context, 3),
                      child: InkWell(
                        onTap: () => setState(() => _images.removeAt(idx)),
                        child: Container(
                          padding: EdgeInsets.all(healthDp(context, 2)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.40),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 9999)),
                          ),
                          child: Icon(
                            Icons.close,
                            size: healthDp(context, 12),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 10),
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '*산업안전보건법 제41조, 고객 응대 보호에 따라 욕설 성적 모욕 비하 등\n부적절한 내용은 상담이 제한 되거나 삭제될 수 있습니다.',
          style: TextStyle(
            color: const Color(0xFF111111),
            fontSize: healthSp(context, 10),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    final h = healthDp(context, 40);
    final r = healthDp(context, 10);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: h,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                    width: healthDp(context, 0.5), color: _kBorder),
                borderRadius: BorderRadius.circular(r),
              ),
            ),
            child: TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 20)),
        Expanded(
          child: Container(
            height: h,
            decoration: ShapeDecoration(
              color: _kPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
            ),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitContact,
              child: _isSubmitting
                  ? SizedBox(
                      width: healthDp(context, 18),
                      height: healthDp(context, 18),
                      child: CircularProgressIndicator(
                        strokeWidth: healthDp(context, 2),
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditMode ? '수정' : '등록',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 16),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
