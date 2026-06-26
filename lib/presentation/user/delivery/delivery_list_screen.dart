import 'package:flutter/material.dart';
import 'dart:ui';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'widgets/delivery_status_filter_bar.dart';
import 'widgets/reservation_time_change_popup.dart';
import '../review/review_write_screen.dart';
import '../review/review_write_general_screen.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import 'widgets/delivery_address_change_popup.dart';
import 'widgets/order_flow_dialogs.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 주문내역 화면
class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  // 주문 데이터
  List<OrderListModel> _allOrders = []; // 전체 주문 데이터
  List<OrderListModel> _displayedOrders = []; // 화면에 표시할 주문 데이터
  bool _isLoading = false;
  String _selectedStatus = 'all';
  final ScrollController _scrollController = ScrollController();

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kMuted2 = Color(0xFF898383);
  static const Color _kInk = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 주문 목록 로드 (전체 데이터)
  Future<void> _loadOrders() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 로그인된 사용자 ID 가져오기
      final user = await AuthService.getUser();
      if (user == null) {
        setState(() {
          _allOrders = [];
          _displayedOrders = [];
        });
        return;
      }
      final userId = user.id;
      
      // 전체 주문 데이터 조회 (기간: 전체, 상태: 전체)
      final result = await OrderService.getOrderList(
        mbId: userId,
        period: 0, // 전체 기간
        status: 'all', // 전체 상태
        page: 0,
        size: 1000, // 충분히 큰 값으로 전체 데이터 가져오기
      );
      
      if (result['success'] == true) {
        final ordersList = result['orders'] ?? [];
        List<OrderListModel> allOrders = [];
        if (ordersList is List<OrderListModel>) {
          allOrders = ordersList;
        } else if (ordersList is List) {
          allOrders = ordersList
              .whereType<Map>()
              .map((item) => OrderListModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        
        // 날짜순 내림차순 정렬 (최신순)
        allOrders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
        
        setState(() {
          _allOrders = allOrders;
          _applyFilter();
        });

        // 목록 응답에 배송비가 없거나 0인 경우, 상세 API 기준 배송비로 보정
        _syncDeliveryFeesFromDetail(userId);
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncDeliveryFeesFromDetail(String userId) async {
    if (_allOrders.isEmpty) return;

    bool changed = false;
    final updated = <OrderListModel>[];

    for (final order in _allOrders) {
      if (order.deliveryFee > 0) {
        updated.add(order);
        continue;
      }

      try {
        final detailResult = await OrderService.getOrderDetail(
          odId: order.odId,
          mbId: userId,
        );

        if (detailResult['success'] == true && detailResult['order'] is OrderDetailModel) {
          final detail = detailResult['order'] as OrderDetailModel;
          if (detail.deliveryFee > 0) {
            changed = true;
            updated.add(
              OrderListModel(
                odId: order.odId,
                orderDate: order.orderDate,
                orderDateTime: order.orderDateTime,
                displayStatus: order.displayStatus,
                odStatus: order.odStatus,
                totalPrice: order.totalPrice,
                deliveryFee: detail.deliveryFee,
                odCartCount: order.odCartCount,
                isPrescriptionOrder: order.isPrescriptionOrder,
                items: order.items,
                firstProductName: order.firstProductName,
                firstProductOption: order.firstProductOption,
                firstProductQty: order.firstProductQty,
                firstProductPrice: order.firstProductPrice,
              ),
            );
            continue;
          }
        }
      } catch (_) {}

      updated.add(order);
    }

    if (!changed || !mounted) return;
    setState(() {
      _allOrders = updated;
      _applyFilter();
    });
  }
  
  /// 필터 적용
  void _applyFilter() {
    if (_selectedStatus == 'all') {
      // 전체 표시 (내림차순)
      _displayedOrders = List.from(_allOrders);
    } else {
      // 선택된 상태만 필터링
      _displayedOrders = _allOrders.where((order) {
        final displayStatus = order.displayStatus;
        switch (_selectedStatus) {
          case 'payment_waiting':
            return displayStatus == '결제대기중' || order.odStatus == '주문';
          case 'preparing':
            return displayStatus == '배송준비중' || order.odStatus == '입금' || order.odStatus == '준비';
          case 'delivering':
            return displayStatus == '배송중' || order.odStatus == '배송';
          case 'completed':
            return displayStatus == '배송완료' || order.odStatus == '완료';
          case 'exchange':
            return displayStatus.contains('교환') || order.odStatus.contains('교환');
          case 'refund':
            return displayStatus.contains('환불') || order.odStatus.contains('환불');
          case 'cancelled':
            return displayStatus.contains('취소') ||
                order.odStatus.contains('취소') ||
                displayStatus == '주문 취소';
          default:
            return true;
        }
      }).toList();
    }
  }
  
  /// 상태 필터 선택
  void _selectStatus(String status) {
    setState(() {
      _selectedStatus = status;
      _applyFilter();
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '주문 내역'),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: _kPink,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: DeliveryStatusFilterBar(
              selectedKey: _selectedStatus,
              onSelected: _selectStatus,
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: _kPink),
              ),
            )
          else if (_displayedOrders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyStateContent(),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 10),
                healthDp(context, 27),
                healthDp(context, 10),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = _displayedOrders[index];
                    return _buildOrderCard(order);
                  },
                  childCount: _displayedOrders.length,
                ),
              ),
            ),
          if (!_isLoading)
            SliverToBoxAdapter(child: SizedBox(height: healthDp(context, 48))),
        ],
      ),
    );
  }

  /// 주문 카드 위젯
  Widget _buildOrderCard(OrderListModel order) {
    final statusText = _getOrderStatusText(order);

    return Container(
      margin: EdgeInsets.only(bottom: healthDp(context, 10)),
      padding: EdgeInsets.all(healthDp(context, 20)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
        border: Border.all(width: healthDp(context, 1), color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '주문일자: ${order.orderDate}',
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 5)),
                        Text(
                          '주문번호: ${order.odId}',
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _navigateToOrderDetail(order.odId),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '주문상세',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 2)),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: healthDp(context, 16),
                      color: _kInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: _kBorder,
          ),
          SizedBox(height: healthDp(context, 20)),
          ..._buildOrderProductBlocks(order),
          SizedBox(height: healthDp(context, 20)),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (order.deliveryFee > 0) ...[
                  Text(
                    '(배송비: ${PriceFormatter.format(order.deliveryFee)}원)',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 5)),
                ],
                Text(
                  '총 ${PriceFormatter.format(order.totalPrice)}원',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ...(() {
            final actions = _buildOrderCardActions(order);
            if (actions == null) return <Widget>[];
            return <Widget>[
              SizedBox(height: healthDp(context, 20)),
              actions,
            ];
          })(),
        ],
      ),
    );
  }

  /// 한 주문의 상품 행들 (`items` 전부, 없으면 `firstProduct*` 요약 1행)
  List<Widget> _buildOrderProductBlocks(OrderListModel order) {
    if (order.items.isNotEmpty) {
      final widgets = <Widget>[];
      for (var i = 0; i < order.items.length; i++) {
        if (i > 0) widgets.add(SizedBox(height: healthDp(context, 16)));
        final item = order.items[i];
        final showMoreHint =
            order.items.length == 1 && order.odCartCount > 1;
        widgets.add(
          _buildOrderProductLineInk(
            order.odId,
            image: _buildProductImageFromItem(item),
            title: _displayProductTitle(item),
            qtyLine: _qtyLineForItem(item),
            priceText: '${PriceFormatter.format(item.totalPrice)}원',
            moreHint: showMoreHint ? '외 ${order.odCartCount - 1}개 상품' : null,
          ),
        );
      }
      return widgets;
    }

    final qty = order.firstProductQty ?? 1;
    var qtyLine = '수량: $qty';
    final opt = order.firstProductOption;
    if (opt != null && opt.isNotEmpty) {
      qtyLine += ' /$opt';
    }

    return [
      _buildOrderProductLineInk(
        order.odId,
        image: _buildProductImage(order),
        title: order.firstProductName ?? '상품명 없음',
        qtyLine: qtyLine,
        priceText: '${PriceFormatter.format(order.firstProductPrice ?? 0)}원',
        moreHint:
            order.odCartCount > 1 ? '외 ${order.odCartCount - 1}개 상품' : null,
      ),
    ];
  }

  String _displayProductTitle(OrderItem item) {
    final n = item.itName.trim();
    if (n.isNotEmpty) return n;
    final s = item.itSubject.trim();
    if (s.isNotEmpty) return s;
    return '상품명 없음';
  }

  String _qtyLineForItem(OrderItem item) {
    final parts = <String>['수량: ${item.ctQty}'];
    final opt = item.ctOption;
    if (opt != null && opt.trim().isNotEmpty) {
      parts.add(opt.trim());
    }
    return parts.join(' / ');
  }

  Widget _buildOrderProductLineInk(
    String odId, {
    required Widget image,
    required String title,
    required String qtyLine,
    required String priceText,
    String? moreHint,
  }) {
    return InkWell(
      onTap: () => _navigateToOrderDetail(odId),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image,
          SizedBox(width: healthDp(context, 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _kInk,
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
                  qtyLine,
                  style: TextStyle(
                    color: _kMuted2,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  priceText,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (moreHint != null)
                  Padding(
                    padding: EdgeInsets.only(top: healthDp(context, 4)),
                    child: Text(
                      moreHint,
                      style: TextStyle(
                        fontSize: healthSp(context, 10),
                        color: _kMuted2,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageFromItem(OrderItem item) {
    final imageUrl = item.imageUrl;
    final normalizedUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(imageUrl, item.itId)
        : null;

    final thumb = healthDp(context, 80);
    return Container(
      width: thumb,
      height: thumb,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: Image.network(
                normalizedUrl,
                width: thumb,
                height: thumb,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: healthDp(context, 40),
                    color: Colors.grey[400],
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: healthDp(context, 2),
                      color: _kPink,
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: healthDp(context, 40),
              color: Colors.grey[400],
            ),
    );
  }

  /// 카드 하단 액션 — 왼쪽부터 1:핑크/흰 · 2:흰/핑크 · 3:회색/0xFF898686
  Widget? _buildOrderCardActions(OrderListModel order) {
    final isPrescription = order.isPrescriptionOrder;
    final specs = <({String label, VoidCallback? onTap})>[];

    if (_isPaymentStage(order) || _isPreparingStage(order)) {
      specs.add((label: '배송지변경', onTap: () => _changeDeliveryAddress(order.odId)));
      if (isPrescription) {
        specs.add((
          label: '예약시간변경',
          onTap: () => _changeReservationTimeFromList(order.odId),
        ));
      }
      specs.add((label: '주문취소', onTap: () => _cancelOrder(order.odId)));
    } else if (_isDeliveringStage(order)) {
      specs.add((label: '배송조회', onTap: () => _trackDelivery(order.odId)));
      specs.add((label: '수령확인', onTap: () => _confirmPurchase(order.odId)));
    } else if (_isCompletedStage(order)) {
      specs.add((label: '리뷰쓰기', onTap: () => _writeReview(order.odId)));
      specs.add((
        label: '교환/환불',
        onTap: () => _openRefundApply(order.odId, isPrescription: order.isPrescriptionOrder),
      ));
    } else if (_isExchangeStage(order)) {
      specs.add((label: '교환취소', onTap: null));
    } else if (_isRefundStage(order)) {
      specs.add((label: '환불취소', onTap: null));
    }

    if (specs.isEmpty) return null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = specs.length;
        final gap = healthDp(context, 10);
        final designW = healthDp(context, 87);
        final btnH = healthDp(context, 34);
        final totalGaps = count > 1 ? (count - 1) * gap : 0.0;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final needed = count * designW + totalGaps;
        final btnW = needed <= maxW
            ? designW
            : ((maxW - totalGaps) / count).clamp(0.0, designW);

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _cardActionButton(
                label: specs[i].label,
                index: i,
                onTap: specs[i].onTap,
                width: btnW,
                height: btnH,
              ),
            ],
          ],
        );
      },
    );
  }

  ({Color background, Color foreground, Color? border}) _cardActionColors(int index) {
    if (index == 0) {
      return (background: _kPink, foreground: Colors.white, border: null);
    }
    if (index == 1) {
      return (background: Colors.white, foreground: _kPink, border: _kPink);
    }
    return (background: _kBorder, foreground: _kMuted, border: null);
  }

  TextStyle _cardActionTextStyle({required Color color, bool enabled = true}) {
    return TextStyle(
      color: color.withValues(alpha: enabled ? 1 : 0.45),
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }

  SizedBox _cardActionSizedBox({
    required Widget child,
    required double width,
    required double height,
  }) {
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _cardActionButton({
    required String label,
    required int index,
    VoidCallback? onTap,
    required double width,
    required double height,
  }) {
    final enabled = onTap != null;
    final colors = _cardActionColors(index);
    final bg = enabled
        ? colors.background
        : colors.background.withValues(
            alpha: colors.background == Colors.white ? 1 : 0.45,
          );
    final fg = enabled ? colors.foreground : colors.foreground.withValues(alpha: 0.45);
    final borderColor = colors.border == null
        ? null
        : (enabled ? colors.border! : colors.border!.withValues(alpha: 0.35));

    return _cardActionSizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              border: borderColor == null
                  ? null
                  : Border.all(
                      width: healthDp(context, 1),
                      color: borderColor,
                    ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 2)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: _cardActionTextStyle(color: fg, enabled: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateContent() {
    final statusText = _selectedStatus == 'all'
        ? '주문'
        : _getStatusText(_selectedStatus);
    return CenteredEmptyState(
      icon: Icons.inbox_outlined,
      message: '$statusText 내역이 없습니다',
    );
  }

  /// 상태 텍스트 가져오기
  String _getStatusText(String status) {
    switch (status) {
      case 'payment_waiting':
        return '결제대기중';
      case 'preparing':
        return '배송준비중';
      case 'delivering':
        return '배송중';
      case 'completed':
        return '배송완료';
      case 'exchange':
        return '교환중';
      case 'refund':
        return '환불중';
      case 'cancelled':
        return '주문 취소';
      default:
        return '주문';
    }
  }

  String _getOrderStatusText(OrderListModel order) {
    if (_isCompletedStage(order)) return '배송완료';
    if (_isDeliveringStage(order)) return '배송중';
    if (_isPreparingStage(order)) return '배송준비중';
    if (_isPaymentStage(order)) return '결제대기중';
    return order.displayStatus;
  }

  bool _isPaymentStage(OrderListModel order) {
    return order.displayStatus == '결제완료' ||
        order.displayStatus == '결제대기중' ||
        order.odStatus == '주문';
  }

  bool _isPreparingStage(OrderListModel order) {
    return order.displayStatus == '배송준비중' ||
        order.odStatus == '입금' ||
        order.odStatus == '준비';
  }

  bool _isDeliveringStage(OrderListModel order) {
    return order.displayStatus == '배송중' || order.odStatus == '배송';
  }

  bool _isCompletedStage(OrderListModel order) {
    return order.displayStatus == '배송완료' || order.odStatus == '완료';
  }

  bool _isExchangeStage(OrderListModel order) {
    return order.displayStatus.contains('교환') || order.odStatus.contains('교환');
  }

  bool _isRefundStage(OrderListModel order) {
    return order.displayStatus.contains('환불') || order.odStatus.contains('환불');
  }

  /// 주문 상세 화면으로 이동
  void _navigateToOrderDetail(String orderNumber) {
    Navigator.pushNamed(
      context,
      '/order-detail',
      arguments: {'orderNumber': orderNumber},
    );
  }

  /// 주문 취소
  Future<void> _cancelOrder(String odId) async {
    final user = await AuthService.getUser();
    if (user == null) return;

    final ok = await OrderFlowDialogs.runOrderCancelFlow(
      context,
      odId: odId,
      mbId: user.id,
    );
    if (ok && mounted) _loadOrders();
  }

  /// 배송 조회
  Future<void> _trackDelivery(String odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }
      final userId = user.id;
      
      // 주문 상세 정보 조회
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );
      
      if (result['success'] != true) {
        return;
      }
      
      final orderDetail = result['order'] as OrderDetailModel;
      final companyName = orderDetail.deliveryCompany;
      final trackingNumber = orderDetail.trackingNumber;
      
      // 택배사와 운송장번호 확인
      if (companyName == null || companyName.isEmpty) {
        return;
      }
      
      if (trackingNumber == null || trackingNumber.isEmpty) {
        return;
      }
      
      // 지원하는 택배사인지 확인
      if (!DeliveryTracker.isSupported(companyName)) {
        return;
      }
      
      // 배송 조회 페이지 열기
      await DeliveryTracker.openTrackingPage(companyName, trackingNumber);
    } catch (e) {}
  }

  /// 배송확정 (구매 확정)
  Future<void> _confirmPurchase(String odId) async {
    final ok = await OrderFlowDialogs.showReceiptConfirm(context);
    if (ok != true) return;

    final user = await AuthService.getUser();
    if (user == null) {
      return;
    }

    final result = await OrderService.confirmPurchase(
      odId: odId,
      mbId: user.id,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _loadOrders();
    }
  }

  Future<void> _openRefundApply(String odId, {required bool isPrescription}) async {
    await Navigator.pushNamed(
      context,
      isPrescription ? '/refund' : '/refund-general',
      arguments: {'orderNumber': odId},
    );
  }

  /// 리뷰 쓰기
  Future<void> _writeReview(String odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }
      final userId = user.id;
      
      // 주문 상세 정보 조회
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );
      
      if (result['success'] != true) {
        return;
      }
      
      final orderDetail = result['order'] as OrderDetailModel;
      
      // 리뷰 작성 화면으로 이동
      if (mounted) {
        final isPrescription = orderDetail.isPrescriptionOrder;
        final reviewWritten = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => isPrescription
                ? ReviewWriteScreen(orderDetail: orderDetail)
                : ReviewWriteGeneralScreen(orderDetail: orderDetail),
          ),
        );
        
        // 리뷰 작성 완료 시 주문 목록 새로고침
        if (reviewWritten == true) {
          _loadOrders();
        }
      }
    } catch (e) {}
  }

  Future<void> _changeDeliveryAddress(String odId) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '배송지 변경',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            DeliveryAddressChangePopup(orderId: odId),
          ],
        );
      },
    );
    if (result == true && mounted) {
      _loadOrders();
    }
  }

  /// 상품 이미지 위젯
  Widget _buildProductImage(OrderListModel order) {
    // 첫 번째 상품의 이미지 URL 가져오기
    String? imageUrl;
    if (order.items.isNotEmpty && order.items[0].imageUrl != null) {
      imageUrl = order.items[0].imageUrl;
    }
    
    // 이미지 URL 정규화
    final normalizedUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(imageUrl, order.items.isNotEmpty ? order.items[0].itId : null)
        : null;
    
    final thumb = healthDp(context, 80);
    return Container(
      width: thumb,
      height: thumb,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(healthDp(context, 4)),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: Image.network(
                normalizedUrl,
                width: thumb,
                height: thumb,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: healthDp(context, 40),
                    color: Colors.grey[400],
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: healthDp(context, 2),
                      color: _kPink,
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: healthDp(context, 40),
              color: Colors.grey[400],
            ),
    );
  }

  /// 예약 시간 변경 (주문 목록에서 호출 - 예약 정보 확인 후 화면 이동)
  Future<void> _changeReservationTimeFromList(String odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }

      // 주문 상세 조회하여 예약 정보 확인
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );

      if (result['success'] != true) {
        return;
      }

      final orderDetail = result['order'] as OrderDetailModel;

      // 예약 정보 확인
      if (orderDetail.reservationDate == null || orderDetail.reservationTime == null) {
        return;
      }

      // 예약 시간 변경 팝업 표시
      final changeResult = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '예약시간 변경',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, __) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
              ReservationTimeChangePopup(
                orderId: odId,
                currentDate: orderDetail.reservationDate!,
                currentTime: orderDetail.reservationTime!,
              ),
            ],
          );
        },
      );

      // 예약 시간이 변경되었으면 주문 목록 새로고침
      if (changeResult == true && mounted) {
        _loadOrders();
      }
    } catch (e) {}
  }
}

