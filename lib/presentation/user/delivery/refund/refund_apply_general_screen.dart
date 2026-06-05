import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/widgets/mobile_layout_wrapper.dart';
import 'widgets/refund_apply_photo_utils.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../data/models/delivery/delivery_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import 'refund_reason_status.dart';

/// 헬스케어 스토어(일반) 주문 교환/환불 신청 — 라우트 `/refund-general`
class RefundApplyGeneralScreen extends StatefulWidget {
  final String orderNumber;

  const RefundApplyGeneralScreen({
    super.key,
    required this.orderNumber,
  });

  @override
  State<RefundApplyGeneralScreen> createState() => _RefundApplyGeneralScreenState();
}

class _ProductLineState {
  final OrderItem item;
  bool selected;
  int quantity;

  _ProductLineState({
    required this.item,
    required this.quantity,
  }) : selected = false;
}

class _RefundApplyGeneralScreenState extends State<RefundApplyGeneralScreen> {
  OrderDetailModel? _order;
  bool _loading = true;
  String? _loadError;

  RefundApplyTab _tab = RefundApplyTab.refund;
  final List<_ProductLineState> _lines = [];
  String? _selectedReason;
  final _detailController = TextEditingController();
  final List<XFile?> _photos = [null, null, null];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        setState(() {
          _loadError = '로그인이 필요합니다.';
          _loading = false;
        });
        return;
      }
      final result = await OrderService.getOrderDetail(
        odId: widget.orderNumber,
        mbId: user.id,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        setState(() {
          _loadError = '주문 정보를 불러올 수 없습니다.';
          _loading = false;
        });
        return;
      }
      final order = result['order'] as OrderDetailModel;
      if (order.isPrescriptionOrder) {
        setState(() {
          _loadError = '일반 상품 주문만 이 화면에서 신청할 수 있습니다.';
          _loading = false;
        });
        return;
      }
      _order = order;
      _lines
        ..clear()
        ..addAll(
          order.products.map(
            (p) => _ProductLineState(item: p, quantity: p.ctQty),
          ),
        );
      _selectedReason = RefundReasonStatus.generalReasons.first;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = '주문 정보를 불러올 수 없습니다.';
        _loading = false;
      });
    }
  }

  List<String> get _reasons => RefundReasonStatus.generalReasons;

  int get _selectedTotalPrice {
    var sum = 0;
    for (final line in _lines) {
      if (!line.selected) continue;
      final item = line.item;
      if (item.ctQty <= 0) continue;
      final unit = item.totalPrice ~/ item.ctQty;
      sum += unit * line.quantity;
    }
    return sum;
  }

  void _onTabChanged(RefundApplyTab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _selectedReason = _reasons.first;
    });
  }

  void _submit() {
    final selected = _lines.where((e) => e.selected).toList();
    if (selected.isEmpty) return;
    if (_selectedReason == null || _selectedReason!.isEmpty) return;
    if (_detailController.text.trim().isEmpty) return;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(title: '교환/환불'),
      child: Material(
        color: Colors.white,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(healthDp(context, 27)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: healthSp(context, 14),
                color: RefundReasonStatus.muted,
              ),
            ),
            SizedBox(height: healthDp(context, 16)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeTab(),
          SizedBox(height: healthDp(context, 20)),
          _buildSectionTitle(title: '주문상품 정보'),
          SizedBox(height: healthDp(context, 10)),
          ..._lines.asMap().entries.map((entry) {
            final i = entry.key;
            final line = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _lines.length - 1 ? healthDp(context, 10) : 0),
              child: _buildProductCard(line),
            );
          }),
          if (_lines.any((line) => line.selected)) ...[
            SizedBox(height: healthDp(context, 10)),
            _buildTotalRow(),
          ],
          SizedBox(height: healthDp(context, 20)),
          _buildSectionTitle(title: '사유선택', required: true),
          SizedBox(height: healthDp(context, 10)),
          _buildReasonSection(),
          SizedBox(height: healthDp(context, 20)),
          _buildSectionTitle(title: '상세 사유 입력', required: true),
          SizedBox(height: healthDp(context, 10)),
          _buildDetailInput(),
          SizedBox(height: healthDp(context, 20)),
          _buildSectionTitle(title: '사진 업로드', optionalLabel: '(선택)'),
          SizedBox(height: healthDp(context, 10)),
          _buildPhotoSection(),
          SizedBox(height: healthDp(context, 20)),
          _buildBottomBar(),
          SizedBox(height: healthDp(context, 20)),
        ],
      ),
    );
  }

  Widget _buildTypeTab() {
    return Container(
      decoration: BoxDecoration(
        color: RefundReasonStatus.tabBg,
        borderRadius: BorderRadius.circular(healthDp(context, 20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeTabItem(
              label: '교환신청',
              active: _tab == RefundApplyTab.exchange,
              onTap: () => _onTabChanged(RefundApplyTab.exchange),
            ),
          ),
          Expanded(
            child: _buildTypeTabItem(
              label: '환불신청',
              active: _tab == RefundApplyTab.refund,
              onTap: () => _onTabChanged(RefundApplyTab.refund),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabItem({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 20)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
            border: active
                ? Border.all(
                    width: healthDp(context, 0.5),
                    color: RefundReasonStatus.muted.withValues(alpha: 0.5),
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? RefundReasonStatus.ink : RefundReasonStatus.muted,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitleBar() {
    return Container(
      width: healthDp(context, 1),
      height: healthDp(context, 16),
      color: RefundReasonStatus.ink,
    );
  }

  Widget _buildSectionTitle({
    required String title,
    bool required = false,
    String? optionalLabel,
  }) {
    return Row(
      children: [
        _sectionTitleBar(),
        SizedBox(width: healthDp(context, 8)),
        if (title.isNotEmpty)
          Text(
            title,
            style: TextStyle(
              color: RefundReasonStatus.ink,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: healthDp(context, -1.26),
            ),
          ),
        if (required) ...[
          SizedBox(width: healthDp(context, 5)),
          Text(
            '*필수',
            style: TextStyle(
              color: RefundReasonStatus.required,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
        if (optionalLabel != null) ...[
          SizedBox(width: healthDp(context, 5)),
          Text(
            optionalLabel,
            style: TextStyle(
              color: RefundReasonStatus.muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );
  }

  String _productSubtitle(OrderItem product) {
    final opt = product.ctOption?.trim();
    if (opt != null && opt.isNotEmpty) return opt;
    return '수량: ${product.ctQty}';
  }

  Widget _buildProductCard(_ProductLineState line) {
    final product = line.item;
    final imageUrl = product.imageUrl != null && product.imageUrl!.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(product.imageUrl, product.itId)
        : null;
    final thumb = healthDp(context, 80);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: BoxDecoration(
        border: Border.all(width: healthDp(context, 1), color: RefundReasonStatus.border),
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => line.selected = !line.selected),
                child: Container(
                  width: healthDp(context, 16),
                  height: healthDp(context, 16),
                  decoration: BoxDecoration(
                    color: line.selected ? RefundReasonStatus.pink : Colors.white,
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                    border: Border.all(
                      width: healthDp(context, 1),
                      color: line.selected ? RefundReasonStatus.pink : RefundReasonStatus.borderSolid,
                    ),
                  ),
                  child: line.selected
                      ? Icon(Icons.check, size: healthDp(context, 12), color: Colors.white)
                      : null,
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 4)),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _productThumbPlaceholder(thumb),
                      )
                    : _productThumbPlaceholder(thumb),
              ),
              SizedBox(width: healthDp(context, 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itName,
                      style: TextStyle(
                        color: RefundReasonStatus.ink,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthDp(context, -1.26),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text(
                      _productSubtitle(product),
                      style: TextStyle(
                        color: RefundReasonStatus.mutedLabel,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text(
                      '${PriceFormatter.format(product.totalPrice)}원',
                      style: TextStyle(
                        color: RefundReasonStatus.ink,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (line.selected && product.ctQty >= 2) ...[
            SizedBox(height: healthDp(context, 10)),
            Align(
              alignment: Alignment.centerRight,
              child: _buildQtyStepper(
                value: line.quantity,
                min: 1,
                max: product.ctQty,
                onChanged: (v) => setState(() => line.quantity = v),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productThumbPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: RefundReasonStatus.borderSolid.withValues(alpha: 0.3),
      child: Icon(Icons.image, color: RefundReasonStatus.muted, size: healthDp(context, 24)),
    );
  }

  Widget _buildQtyStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: BoxDecoration(
        color: RefundReasonStatus.stepperBg,
        borderRadius: BorderRadius.circular(healthDp(context, 20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyStepperBtn(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 8)),
            child: Text(
              '$value',
              style: TextStyle(
                color: const Color(0xFF191C1D),
                fontSize: healthSp(context, 16),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _qtyStepperBtn(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  Widget _qtyStepperBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      elevation: 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: SizedBox(
          width: healthDp(context, 20),
          height: healthDp(context, 20),
          child: Icon(
            icon,
            size: healthDp(context, 14),
            color: enabled ? RefundReasonStatus.pink : RefundReasonStatus.pink.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      padding: EdgeInsets.only(top: healthDp(context, 10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(width: 1, color: Color(0x7F1A1A1A))),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '총 ${PriceFormatter.format(_selectedTotalPrice)}원',
          style: TextStyle(
            color: RefundReasonStatus.ink,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      children: [
        for (var i = 0; i < _reasons.length; i++) ...[
          if (i > 0) SizedBox(height: healthDp(context, 10)),
          _buildReasonTile(
            label: _reasons[i],
            selected: _selectedReason == _reasons[i],
            onTap: () => setState(() => _selectedReason = _reasons[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildReasonTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 14),
          ),
          decoration: BoxDecoration(
            color: selected ? RefundReasonStatus.pinkTint : Colors.white,
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
            border: Border.all(
              width: healthDp(context, 1),
              color: selected ? RefundReasonStatus.pinkAccent : RefundReasonStatus.borderSolid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: healthDp(context, 24),
                height: healthDp(context, 24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? RefundReasonStatus.pinkAccent : Colors.transparent,
                  border: Border.all(
                    width: healthDp(context, 2),
                    color: selected ? RefundReasonStatus.pinkAccent : RefundReasonStatus.borderSolid,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: healthDp(context, 14), color: Colors.white)
                    : null,
              ),
              SizedBox(width: healthDp(context, 10)),
              Text(
                label,
                style: TextStyle(
                  color: RefundReasonStatus.ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailInput() {
    final hint = _tab == RefundApplyTab.exchange
        ? '교환 사유를 작성해주세요(100자 이내)'
        : '환불 사유를 작성해주세요(100자 이내)';

    final pad = healthDp(context, 20);
    return Container(
      width: double.infinity,
      height: healthDp(context, 102),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: healthDp(context, 1), color: RefundReasonStatus.border),
        borderRadius: BorderRadius.circular(healthDp(context, 7)),
      ),
      child: TextField(
        controller: _detailController,
        maxLength: 100,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          color: RefundReasonStatus.ink,
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
          hintText: hint,
          hintStyle: TextStyle(
            color: RefundReasonStatus.muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            letterSpacing: healthDp(context, -0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    const maxPhotos = 3;
    final children = <Widget>[];
    for (var i = 0; i < maxPhotos; i++) {
      final file = i < _photos.length ? _photos[i] : null;
      if (file != null) {
        children.add(
          RefundApplyPhotoUtils.buildThumb(context, file, () => setState(() => _photos[i] = null)),
        );
      }
    }
    if (_photos.whereType<XFile>().length < maxPhotos) {
      children.add(
        RefundApplyPhotoUtils.buildAddTile(
          context,
          onAddTap: (anchor) => RefundApplyPhotoUtils.pickPhoto(
            context,
            anchor,
            (file) {
              if (file != null) {
                setState(() {
                  final idx = _photos.indexWhere((e) => e == null);
                  if (idx >= 0) _photos[idx] = file;
                });
              }
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefundApplyPhotoUtils.buildPhotoRow(context: context, children: children),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(
            color: RefundReasonStatus.muted,
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
              child: Container(
                height: healthDp(context, 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  border: Border.all(
                    width: healthDp(context, 0.5),
                    color: RefundReasonStatus.borderSolid,
                  ),
                ),
                child: Text(
                  '취소',
                  style: TextStyle(
                    color: RefundReasonStatus.muted,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 20)),
        Expanded(
          child: Material(
            color: RefundReasonStatus.pink,
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: InkWell(
              onTap: _submit,
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
              child: Container(
                height: healthDp(context, 40),
                alignment: Alignment.center,
                child: Text(
                  '신청하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
