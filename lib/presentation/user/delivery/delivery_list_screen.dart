import 'package:flutter/material.dart';
import 'dart:ui';
import '../../common/widgets/mobile_layout_wrapper.dart';
// import '../../common/widgets/app_footer.dart';
import '../../common/widgets/app_bar.dart';
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 목록을 불러올 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      print('❌ 주문 목록 로드 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문 목록을 불러오는 중 오류가 발생했습니다.')),
        );
      }
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
          body: Column(
            children: [
              DeliveryStatusFilterBar(
                selectedKey: _selectedStatus,
                onSelected: _selectStatus,
              ),
              Expanded(child: _buildOrderList()),
            ],
          ),
        ),
      ),
    );
  }

  /// 주문 목록 위젯
  Widget _buildOrderList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPink),
      );
    }

    if (_displayedOrders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: _kPink,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 주문 리스트 (padding 적용)
          SliverPadding(
            padding: const EdgeInsets.all(16),
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
          
          // Footer
          // const SliverToBoxAdapter(
          //   child: Column(
          //     children: [
          //       SizedBox(height: 300),
          //       AppFooter(),
          //     ],
          //   ),
          // ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  /// 주문 카드 위젯
  Widget _buildOrderCard(OrderListModel order) {
    final statusText = _getOrderStatusText(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(width: 1, color: _kBorder),
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
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 14,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '주문일자: ${order.orderDate}',
                          style: const TextStyle(
                            color: _kInk,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '주문번호: ${order.odId}',
                          style: const TextStyle(
                            color: _kInk,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
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
                    const Text(
                      '주문상세',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _kInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(width: double.infinity, height: 1, color: _kBorder),
          const SizedBox(height: 20),
          ..._buildOrderProductBlocks(order),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (order.deliveryFee > 0) ...[
                  Text(
                    '(배송비: ${PriceFormatter.format(order.deliveryFee)}원)',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  '총 ${PriceFormatter.format(order.totalPrice)}원',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...(() {
            final actions = _buildOrderCardActions(order);
            if (actions == null) return <Widget>[];
            return <Widget>[
              const SizedBox(height: 20),
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
        if (i > 0) widgets.add(const SizedBox(height: 16));
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
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.26,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  qtyLine,
                  style: const TextStyle(
                    color: _kMuted2,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (moreHint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      moreHint,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kMuted2,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
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

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                normalizedUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: 40,
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
                      strokeWidth: 2,
                      color: _kPink,
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: 40,
              color: Colors.grey[400],
            ),
    );
  }

  /// 카드 하단 액션 (상태별 최대 3버튼, 디자인 스펙: 분홍 / 외곽분홍 / 회색)
  Widget? _buildOrderCardActions(OrderListModel order) {
    final isPrescription = order.isPrescriptionOrder;

    List<Widget> rowChildren() {
      final out = <Widget>[];
      void gap() {
        if (out.isNotEmpty) out.add(const SizedBox(width: 10));
      }

      void add(Widget w) {
        gap();
        out.add(w);
      }

      // 결제대기중 / 배송준비중
      if (_isPaymentStage(order) || _isPreparingStage(order)) {
        // 공통: 배송지변경 + 주문취소
        add(_cardActionPrimary('배송지변경', () => _changeDeliveryAddress(order.odId)));

        // 비대면(처방) 주문만 예약시간변경 노출
        if (isPrescription) {
          add(_cardActionOutline('예약시간변경', () => _changeReservationTimeFromList(order.odId)));
        } else {
          add(_cardActionOutline('주문취소', () => _cancelOrder(order.odId)));
          return out;
        }

        add(_cardActionGray('주문취소', () => _cancelOrder(order.odId)));
        return out;
      }

      // 배송중: 배송조회 + 수령확인
      if (_isDeliveringStage(order)) {
        add(_cardActionPrimary('수령확인', () => _confirmPurchase(order.odId)));
        add(_cardActionOutline('배송조회', () => _trackDelivery(order.odId)));
        return out;
      }

      // 배송완료: 교환/환불 + 리뷰쓰기
      if (_isCompletedStage(order)) {
        add(_cardActionOutline('교환/환불', null));
        add(_cardActionGray('리뷰쓰기', () => _writeReview(order.odId)));
        return out;
      }

      // 교환중: 교환취소
      if (_isExchangeStage(order)) {
        add(_cardActionGray('교환취소', null));
        return out;
      }

      // 환불중: 환불취소
      if (_isRefundStage(order)) {
        add(_cardActionGray('환불취소', null));
        return out;
      }
      return out;
    }

    final children = rowChildren();
    if (children.isEmpty) return null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _cardActionPrimary(String label, VoidCallback? onTap) {
    return Expanded(
      child: Opacity(
        opacity: onTap != null ? 1 : 0.45,
        child: Material(
          color: _kPink,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardActionOutline(String label, VoidCallback? onTap) {
    return Expanded(
      child: Opacity(
        opacity: onTap != null ? 1 : 0.45,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(width: 1, color: _kPink),
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kPink,
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardActionGray(String label, VoidCallback? onTap) {
    return Expanded(
      child: Material(
        color: _kBorder,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    final statusText = _selectedStatus == 'all'
        ? '주문'
        : _getStatusText(_selectedStatus);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$statusText 내역이 없습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),
                  // const AppFooter(),
                ],
              ),
            ),
          ),
        );
      },
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
    final ok = await OrderFlowDialogs.showOrderCancelConfirm(context);
    if (ok != true) return;

    final user = await AuthService.getUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    final result = await OrderService.cancelOrder(
      odId: odId,
      mbId: user.id,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      await OrderFlowDialogs.showOrderCancelSuccess(context);
      if (mounted) _loadOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '주문 취소에 실패했습니다.')),
      );
    }
  }

  /// 배송 조회
  Future<void> _trackDelivery(String odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }
      final userId = user.id;
      
      // 주문 상세 정보 조회
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );
      
      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.')),
          );
        }
        return;
      }
      
      final orderDetail = result['order'] as OrderDetailModel;
      final companyName = orderDetail.deliveryCompany;
      final trackingNumber = orderDetail.trackingNumber;
      
      // 택배사와 운송장번호 확인
      if (companyName == null || companyName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('택배사 정보가 없습니다.')),
          );
        }
        return;
      }
      
      if (trackingNumber == null || trackingNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('운송장번호가 없습니다.')),
          );
        }
        return;
      }
      
      // 지원하는 택배사인지 확인
      if (!DeliveryTracker.isSupported(companyName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$companyName은(는) 지원하지 않는 택배사입니다.')),
          );
        }
        return;
      }
      
      // 배송 조회 페이지 열기
      final success = await DeliveryTracker.openTrackingPage(companyName, trackingNumber);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배송 조회 페이지를 열 수 없습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('배송 조회 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  /// 배송확정 (구매 확정)
  Future<void> _confirmPurchase(String odId) async {
    final ok = await OrderFlowDialogs.showReceiptConfirm(context);
    if (ok != true) return;

    final user = await AuthService.getUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    final result = await OrderService.confirmPurchase(
      odId: odId,
      mbId: user.id,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? '수령 확인 처리되었습니다.'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );

    if (result['success'] == true) {
      _loadOrders();
    }
  }

  /// 리뷰 쓰기
  Future<void> _writeReview(String odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }
      final userId = user.id;
      
      // 주문 상세 정보 조회
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );
      
      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.')),
          );
        }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 작성 화면을 열 수 없습니다: $e')),
        );
      }
    }
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
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                normalizedUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: 40,
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
                      strokeWidth: 2,
                      color: _kPink,
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: 40,
              color: Colors.grey[400],
            ),
    );
  }

  /// 예약 정보 확인 (주문 상세 조회)
  Future<Map<String, dynamic>> _checkReservationInfo(String odId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {'hasReservation': false};
      }

      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );

      // 404 에러나 실패한 경우 조용히 false 반환 (에러 로그는 서비스에서 처리)
      if (result['success'] != true) {
        return {'hasReservation': false};
      }

      final orderDetail = result['order'] as OrderDetailModel;
      final hasReservation = orderDetail.reservationDate != null && 
                            orderDetail.reservationTime != null;
      
      return {
        'hasReservation': hasReservation,
        'reservationDate': orderDetail.reservationDate,
        'reservationTime': orderDetail.reservationTime,
      };
    } catch (e) {
      // 에러 발생 시 조용히 false 반환 (콘솔 에러는 이미 출력됨)
      return {'hasReservation': false};
    }
  }

  /// 예약 시간 변경 (주문 목록에서 호출 - 예약 정보 확인 후 화면 이동)
  Future<void> _changeReservationTimeFromList(String odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      // 주문 상세 조회하여 예약 정보 확인
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );

      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final orderDetail = result['order'] as OrderDetailModel;

      // 예약 정보 확인
      if (orderDetail.reservationDate == null || orderDetail.reservationTime == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('예약 정보가 없는 주문입니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 시간 변경 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 예약 시간 변경 (예약 정보를 이미 알고 있는 경우)
  Future<void> _changeReservationTime(String odId, String currentDate, String currentTime) async {
    final result = await showGeneralDialog<bool>(
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
              currentDate: currentDate,
              currentTime: currentTime,
            ),
          ],
        );
      },
    );

    // 예약 시간이 변경되었으면 주문 목록 새로고침
    if (result == true && mounted) {
      _loadOrders();
    }
  }
}

