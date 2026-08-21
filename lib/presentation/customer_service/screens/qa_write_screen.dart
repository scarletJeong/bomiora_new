import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_picker_utils.dart';
import '../../../data/services/qa_service.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/dropdown_btn.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';
import 'qa_item_select_screen.dart';

class QaWriteScreen extends StatefulWidget {
  const QaWriteScreen({super.key, this.draft, this.prefilledDraft});

  /// 상품이 이미 정해진 경우(주문내역 진입 등)
  final QaInquiryDraft? draft;
  final QaInquiryDraft? prefilledDraft;

  @override
  State<QaWriteScreen> createState() => _QaWriteScreenState();
}

class _QaWriteScreenState extends State<QaWriteScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _border = Color(0xFFF0F0F0);
  static const String _font = 'Gmarket Sans TTF';
  static const int _maxContentLength = 500;
  static const int _maxImages = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const List<String> _requiredPhotoLabels = [
    '제품사진 \n추가하기',
    '운송장 \n추가하기',
    '택배상자 \n추가하기',
  ];

  final TextEditingController _contentController = TextEditingController();
  final List<XFile> _images = [];
  final List<XFile?> _requiredPhotos = List<XFile?>.filled(3, null);

  String? _selectedInquiryType;
  String? _selectedDetailType;
  QaInquiryDraft? _selectedProduct;
  bool _sending = false;

  bool get _isLockedProduct =>
      (widget.prefilledDraft ?? widget.draft)?.hasTarget == true;

  bool get _hasInquiryType => (_selectedInquiryType ?? '').trim().isNotEmpty;

  bool get _isEtcInquiry => (_selectedInquiryType ?? '').trim() == '기타';

  bool get _hasDetailType => (_selectedDetailType ?? '').trim().isNotEmpty;

  bool get _hasSelectedProduct => _selectedProduct?.hasTarget == true;

  List<String> get _inquiryTypeOptions => QaInquiryDraft.inquiryTypes;

  List<String> get _detailOptions {
    if (!_hasInquiryType || _isEtcInquiry) return const [];
    return QaInquiryDraft.detailOptionsForInquiryType(_selectedInquiryType!);
  }

  bool get _canOpenItemSelect =>
      !_isLockedProduct && !_isEtcInquiry && _hasDetailType;

  bool get _showCompose =>
      _isEtcInquiry || (_hasInquiryType && _hasDetailType && _hasSelectedProduct);

  bool get _isPhotoRequired =>
      (_selectedInquiryType ?? '').trim() == '배송' &&
      (_selectedDetailType ?? '').trim() == '배송 오류';

  bool get _canSubmit =>
      _showCompose &&
      !_sending &&
      _contentController.text.trim().isNotEmpty &&
      (!_isPhotoRequired || _requiredPhotos.any((e) => e != null));

  String get _productFieldLabel {
    final name = (_selectedProduct?.productName ?? '').trim();
    if (name.isNotEmpty) return name;
    return '상품을 선택해주세요';
  }

  bool get _showAfterHoursNotice {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    return totalMinutes >= (17 * 60 + 30);
  }

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.prefilledDraft ?? widget.draft;
    _contentController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _openProductSelect() async {
    if (!_canOpenItemSelect) return;

    final inquiryType = (_selectedInquiryType ?? '').trim();
    final detailType = (_selectedDetailType ?? '').trim();

    final selected = await Navigator.push<QaInquiryDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => QaItemSelectScreen(
          majorCategory: inquiryType,
          detailCategory: detailType,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedProduct = selected);
  }

  Future<void> _submit() async {
    if (!_showCompose) {
      AppToastOverlay.show(context, '문의유형과 상품을 선택해주세요.');
      return;
    }

    final text = _contentController.text.trim();
    if (text.isEmpty) {
      AppToastOverlay.show(context, '문의 내용을 입력해주세요.');
      return;
    }
    if (_isPhotoRequired && !_requiredPhotos.any((e) => e != null)) {
      AppToastOverlay.show(context, '배송 오류 문의는 사진 첨부가 필요합니다.');
      return;
    }

    final inquiryType = (_selectedInquiryType ?? '').trim();
    final product = _selectedProduct;
    final draft = QaInquiryDraft(
      category: _isEtcInquiry ? '기타' : (product?.category ?? '상품'),
      majorCategory: inquiryType,
      detailCategory: _selectedDetailType,
      itId: product?.itId,
      productName: product?.productName,
      brandName: product?.brandName,
      imageUrl: product?.imageUrl,
      price: product?.price,
      odId: product?.odId,
      orderDate: product?.orderDate,
      optionText: product?.optionText,
      itSubject: product?.itSubject,
      selectTabLabel: product?.selectTabLabel,
      cardItems: product?.cardItems ?? const [],
    );

    setState(() => _sending = true);
    try {
      final attachPhotos = <XFile>[
        if (_isPhotoRequired)
          ..._requiredPhotos.whereType<XFile>()
        else
          ..._images,
      ];
      final result = await QaService.create(
        subject: draft.buildSubject(text),
        content: draft.buildContent(text),
        primaryType: (draft.majorCategory ?? draft.category).trim(),
        detailType: draft.detailCategory?.trim(),
        images: attachPhotos,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        AppToastOverlay.show(context, '작성하신 내용이 정상적으로 접수되었습니다.');
        Navigator.pop(context, true);
      } else {
        AppToastOverlay.show(
          context,
          result['message']?.toString() ?? '문의 전송에 실패했습니다.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToastOverlay.show(context, '문의 전송 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openPhotoSourceDropdown(BuildContext anchorContext, {int? slotIndex}) {
    if (!_isPhotoRequired && _images.length >= _maxImages) {
      AppToastOverlay.show(context, '사진은 최대 3장까지 업로드할 수 있습니다.');
      return;
    }
    ImagePickerUtils.showPhotoSourceDropdown(
      context: context,
      anchorContext: anchorContext,
      onImageSelected: (image) => _applyPickedImage(image, slotIndex: slotIndex),
    );
  }

  Future<void> _applyPickedImage(XFile? image, {int? slotIndex}) async {
    if (image == null || !mounted) return;
    if (!_isPhotoRequired && _images.length >= _maxImages) {
      AppToastOverlay.show(context, '사진은 최대 3장까지 업로드할 수 있습니다.');
      return;
    }
    try {
      final bytes = await image.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;
        AppToastOverlay.show(context, '파일당 5MB 이하만 첨부할 수 있습니다.');
        return;
      }
      setState(() {
        if (_isPhotoRequired && slotIndex != null) {
          _requiredPhotos[slotIndex] = image;
        } else {
          _images.add(image);
        }
      });
    } catch (_) {
      if (!mounted) return;
      AppToastOverlay.show(context, '이미지를 불러오지 못했습니다.');
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
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: _ink,
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: true,
            appBar: HealthAppBar(
              title: '1:1 문의',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showAfterHoursNotice)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: healthDp(context, 10)),
                      decoration: ShapeDecoration(
                        color: const Color(0xFFFFF9F9),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: healthDp(context, 1),
                            color: _border,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 20),
                        vertical: healthDp(context, 12),
                      ),
                      child: Text(
                        '· 평일 당일 17시30분 이후 접수건은 익일 오전 9시30분 이후 답변 가능\n  (공휴일, 주말 제외)',
                        style: TextStyle(
                          color: const Color(0xFF555555),
                          fontSize: healthSp(context, 10),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        healthDp(context, 20),
                        healthDp(context, 10),
                        healthDp(context, 20),
                        healthDp(context, 20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '안녕하세요. \n보미오라 고객센터입니다.',
                            style: TextStyle(
                              color: _ink,
                              fontSize: healthSp(context, 20),
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 5)),
                          Text(
                            '무엇을 도와드릴까요?',
                            style: TextStyle(
                              color: const Color(0xFF888888),
                              fontSize: healthSp(context, 13),
                              fontFamily: _font,
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          Row(
                            children: [
                              Expanded(
                                child: _LandingDropdown(
                                  hint: '문의 유형 선택',
                                  value: _selectedInquiryType,
                                  items: _inquiryTypeOptions,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedInquiryType = value;
                                      _selectedDetailType = null;
                                      if (value == '기타') {
                                        _selectedProduct = null;
                                      }
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: healthDp(context, 10)),
                              Expanded(
                                child: _LandingDropdown(
                                  hint: _isEtcInquiry
                                      ? '상세내용 선택없음'
                                      : '상세 내용 선택',
                                  value: _isEtcInquiry
                                      ? null
                                      : _selectedDetailType,
                                  items: _detailOptions,
                                  enabled: _hasInquiryType && !_isEtcInquiry,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDetailType = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (!_isEtcInquiry) ...[
                            SizedBox(height: healthDp(context, 10)),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: healthDp(context, 45),
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: healthDp(context, 16),
                                    ),
                                    decoration: ShapeDecoration(
                                      color: const Color(0xFFFAFAFA),
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          width: healthDp(context, 1),
                                          color: const Color(0xFFE0E0E0),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          healthDp(context, 10),
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _productFieldLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _hasSelectedProduct
                                            ? _ink
                                            : const Color(0xFF808080),
                                        fontSize: healthSp(context, 14),
                                        fontFamily: _font,
                                        fontWeight: FontWeight.w300,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: healthDp(context, 8)),
                                InkWell(
                                  onTap: _canOpenItemSelect
                                      ? _openProductSelect
                                      : null,
                                  borderRadius: BorderRadius.circular(
                                    healthDp(context, 6),
                                  ),
                                  child: Container(
                                    height: healthDp(context, 45),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: healthDp(context, 18),
                                    ),
                                    alignment: Alignment.center,
                                    decoration: ShapeDecoration(
                                      color: _canOpenItemSelect
                                          ? _pink
                                          : const Color(0xFFF1F1F1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          healthDp(context, 6),
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '상품선택',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _canOpenItemSelect
                                            ? Colors.white
                                            : const Color(0xFFC0C0C0),
                                        fontSize: healthSp(context, 13),
                                        fontFamily: _font,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_showCompose) ...[
                            SizedBox(height: healthDp(context, 20)),
                            _buildContentSection(context),
                            SizedBox(height: healthDp(context, 10)),
                            _buildPhotoSection(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    minimum: EdgeInsets.fromLTRB(
                      healthDp(context, 20),
                      healthDp(context, 0),
                      healthDp(context, 20),
                      healthDp(context, 5),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: healthDp(context, 45),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _BottomButton(
                              label: '취소',
                              bg: Colors.white,
                              fg: const Color(0xFF555555),
                              borderColor: const Color(0xFFDCDCDC),
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          SizedBox(width: healthDp(context, 10)),
                          Expanded(
                            flex: 3,
                            child: _BottomButton(
                              label: '문의하기',
                              bg: _canSubmit
                                  ? _pink
                                  : const Color(0xFFD2D2D2),
                              fg: Colors.white,
                              onTap: _sending ? null : _submit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final count = _contentController.text.characters.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            const _SectionTitle(label: '문의내용', fontSize: 15),
        SizedBox(height: healthDp(context, 5)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 14)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0xFFE0E0E0),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: healthDp(context, 120),
                child: TextField(
                  controller: _contentController,
                  enabled: !_sending,
                  maxLines: null,
                  expands: true,
                  maxLength: _maxContentLength,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText:
                        '문의하실 내용을 구체적으로 적어주시면\n정확하고 빠른 답변이 가능합니다.',
                    hintStyle: TextStyle(
                      color: const Color(0x7F1B1B1B),
                      fontSize: healthSp(context, 14),
                      fontFamily: _font,
                      fontWeight: FontWeight.w300,
                      height: 1.6,
                    ),
                  ),
                  style: TextStyle(
                    color: const Color(0xFF1B1B1B),
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$count / $_maxContentLength',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: const Color(0xFFAAAAAA),
                    fontSize: healthSp(context, 12),
                    fontFamily: _font,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final slot = healthDp(context, 76);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          label: '사진 업로드',
          fontSize: 14,
          trailing: _isPhotoRequired ? '(필수)' : '(선택)',
          trailingColor: _isPhotoRequired
              ? const Color(0xFFFF5A8D)
              : const Color(0xFF898686),
        ),
        SizedBox(height: healthDp(context, 5)),
        Row(
          children: [
            if (_isPhotoRequired)
              for (var i = 0; i < _maxImages; i++) ...[
                if (i > 0) SizedBox(width: healthDp(context, 8)),
                if (_requiredPhotos[i] != null)
                  _PhotoThumb(
                    file: _requiredPhotos[i]!,
                    size: slot,
                    onRemove: () => setState(() => _requiredPhotos[i] = null),
                  )
                else
                  Builder(
                    builder: (anchorContext) {
                      return _PhotoAddSlot(
                        size: slot,
                        label: _requiredPhotoLabels[i],
                        onTap: () => _openPhotoSourceDropdown(
                          anchorContext,
                          slotIndex: i,
                        ),
                      );
                    },
                  ),
              ]
            else ...[
              Builder(
                builder: (anchorContext) {
                  return _PhotoAddSlot(
                    size: slot,
                    onTap: () => _openPhotoSourceDropdown(anchorContext),
                  );
                },
              ),
              for (var i = 0; i < _images.length; i++) ...[
                SizedBox(width: healthDp(context, 8)),
                _PhotoThumb(
                  file: _images[i],
                  size: slot,
                  onRemove: () => setState(() => _images.removeAt(i)),
                ),
              ],
            ],
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(
            color: const Color(0xFF898686),
            fontSize: healthSp(context, 10),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.fontSize,
    this.trailing,
    this.trailingColor,
  });

  final String label;
  final double fontSize;
  final String? trailing;
  final Color? trailingColor;

  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: healthDp(context, 3),
          height: healthDp(context, 14),
          decoration: ShapeDecoration(
            color: const Color(0xFFFF5A8D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 99)),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF1B1B1B),
            fontSize: healthSp(context, fontSize),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
            height: 1.5,
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: healthDp(context, 4)),
          Text(
            trailing!,
            style: TextStyle(
              color: trailingColor ?? const Color(0xFF898686),
              fontSize: healthSp(context, 11),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoAddSlot extends StatelessWidget {
  const _PhotoAddSlot({
    required this.size,
    required this.onTap,
    this.label = '사진추가하기',
  });

  final double size;
  final VoidCallback onTap;
  final String label;

  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
        decoration: ShapeDecoration(
          color: const Color(0x99D2D2D2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              AppAssets.addPhotoIcon,
              width: healthDp(context, 28),
              height: healthDp(context, 26),
            ),
            SizedBox(height: healthDp(context, 2)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: healthSp(context, 9),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.file,
    required this.size,
    required this.onRemove,
  });

  final XFile file;
  final double size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: FutureBuilder<Uint8List>(
              future: file.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: size,
                    height: size,
                    color: const Color(0xFFF1F1F1),
                  );
                }
                return Image.memory(
                  snapshot.data!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          Positioned(
            right: healthDp(context, 2),
            top: healthDp(context, 2),
            child: InkWell(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: healthDp(context, 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingDropdown extends StatelessWidget {
  const _LandingDropdown({
    required this.hint,
    required this.items,
    required this.onChanged,
    this.value,
    this.enabled = true,
  });

  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownBtn(
      items: items,
      value: value ?? '',
      emptyText: hint,
      enabled: enabled,
      buttonHeight: healthDp(context, 45),
      itemFontSizeBase: 14,
      itemTextAlign: TextAlign.left,
      borderColor: const Color(0xFFE0E0E0),
      emptyTextColor: const Color(0xFF999999),
      valueTextColor: const Color(0xFF1A1A1A),
      onChanged: (item) => onChanged(item),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({
    required this.label,
    required this.bg,
    required this.fg,
    this.borderColor,
    this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final VoidCallback? onTap;

  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedRectangleBorder(
            side: borderColor != null
                ? BorderSide(width: healthDp(context, 1), color: borderColor!)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(healthDp(context, 8)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
