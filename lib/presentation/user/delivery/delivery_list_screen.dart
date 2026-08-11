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
import '../../../data/services/cart_service.dart';
import '../../../data/services/review_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../shopping/utils/cart_navigation.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../common/widgets/app_network_image.dart';
import 'widgets/delivery_address_change_popup.dart';
import 'widgets/delivery_select_list.dart';
import 'widgets/order_flow_dialogs.dart';
import 'widgets/order_item_subject_groups.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../customer_service/screens/qa_category_screen.dart';
import '../../common/widgets/app_toast_overlay.dart';

/// 주문내역 화면
class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

enum _CardActionStyle { primary, outlinePink, outlineGray }

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  // 주문 데이터
  List<OrderListModel> _allOrders = []; // 전체 주문 데이터
  List<OrderListModel> _displayedOrders = []; // 화면에 표시할 주문 데이터
  bool _isLoading = false;
  String _selectedProductType = DeliveryProductType.prescription;
  String _selectedStatus = 'all';
  final ScrollController _scrollController = ScrollController();

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kMuted2 = Color(0xFF898383);
  static const Color _kInk = Color(0xFF1A1A1A);

  /// 주문상품 추가상품 펼침 키: `{odId}:{parentCtId}`
  final Set<String> _expandedSupplyKeys = {};

  /// 배송완료 주문의 이미 작성된 리뷰 itId `{ odId: [itId...] }`
  Map<String, List<String>> _reviewedItIdsByOd = {};

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

        // 목록 응답에 deliveryFee 포함 — 단건 상세 N+1 불필요
        _syncReviewedItIds(userId, allOrders);
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

  Future<void> _syncReviewedItIds(
    String userId,
    List<OrderListModel> orders,
  ) async {
    final completedOdIds = orders
        .where(_isCompletedStage)
        .map((e) => e.odId)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (completedOdIds.isEmpty) {
      if (mounted) setState(() => _reviewedItIdsByOd = {});
      return;
    }
    final map = await ReviewService.getReviewedItIdsByOrders(
      mbId: userId,
      odIds: completedOdIds,
    );
    if (!mounted) return;
    setState(() => _reviewedItIdsByOd = map);
  }

  bool _listItemIsReviewable(OrderItem item) {
    if (item.itId.trim().isEmpty) return false;
    final parent = (item.parent ?? '').trim();
    if (parent.isNotEmpty) return false;
    final kind = (item.ctKind ?? '').toLowerCase().trim();
    if (kind.startsWith('supply_add|')) return false;
    return true;
  }

  /// 아직 쓸 리뷰가 남아 있으면 true
  bool _canWriteReview(OrderListModel order) {
    final reviewed =
        (_reviewedItIdsByOd[order.odId] ?? const <String>[]).toSet();
    final products = order.items.where(_listItemIsReviewable).toList();
    if (products.isEmpty) {
      // 목록에 상품 상세가 없으면 작성 건수와 장바구니 수로 추정
      if (order.odCartCount > 0 && reviewed.length >= order.odCartCount) {
        return false;
      }
      return true;
    }
    return products.any((p) => !reviewed.contains(p.itId.trim()));
  }

  Future<void> _syncDeliveryFeesFromDetail(String userId) {
    // 목록 API에 deliveryFee가 포함되므로 단건 상세 N+1 호출 불필요
    return Future.value();
  }
  
  /// 필터 적용
  void _applyFilter() {
    final byType = _allOrders.where((order) {
      if (_selectedProductType == DeliveryProductType.prescription) {
        return order.isPrescriptionOrder;
      }
      return !order.isPrescriptionOrder;
    });

    if (_selectedStatus == 'all') {
      _displayedOrders = byType.toList();
      return;
    }

    _displayedOrders = byType.where((order) {
      final displayStatus = order.displayStatus;
      final od = order.odStatus;
      switch (_selectedStatus) {
        case 'payment_waiting':
          return displayStatus == '결제대기중' || od == '주문';
        case 'consultation_done':
          if (displayStatus == '배송중' ||
              displayStatus == '배송완료' ||
              od == '배송' ||
              od == '완료') {
            return false;
          }
          return order.isConsultationDone ||
              displayStatus == '상담완료' ||
              displayStatus.contains('상담');
        case 'paid':
          return !order.isConsultationDone &&
              (displayStatus == '결제완료' ||
                  (od == '입금' && displayStatus != '상담완료') ||
                  (order.isPrescriptionOrder &&
                      od == '준비' &&
                      displayStatus != '상담완료'));
        case 'preparing':
          return !order.isPrescriptionOrder &&
              (displayStatus == '배송준비중' || od == '준비');
        case 'delivering':
          return displayStatus == '배송중' || od == '배송';
        case 'completed':
          return displayStatus == '배송완료' || od == '완료';
        case 'cancelled':
          return displayStatus.contains('취소') ||
              od.contains('취소') ||
              displayStatus == '주문 취소' ||
              displayStatus == '주문취소';
        default:
          return true;
      }
    }).toList();
  }

  void _selectProductType(String productType) {
    if (_selectedProductType == productType) return;
    setState(() {
      _selectedProductType = productType;
      _selectedStatus = 'all';
      _applyFilter();
    });
    _scrollToTop();
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
              selectedProductType: _selectedProductType,
              onProductTypeSelected: _selectProductType,
              selectedKey: _selectedStatus,
              onSelected: _selectStatus,
              statusEntries: _selectedProductType == DeliveryProductType.general
                  ? DeliveryStatusFilterBar.generalStatusEntries
                  : DeliveryStatusFilterBar.prescriptionStatusEntries,
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
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
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
                    SizedBox(height: healthDp(context, 10)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '주문일자: ${order.orderDate}',
                          style: TextStyle(
                            color: _kMuted,
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
                            color: _kMuted,
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
                onTap: () => _navigateToOrderDetail(order),
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
          ..._buildOrderProductBlocks(order),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: _kBorder,
          ),
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '총 ${PriceFormatter.format(order.totalPrice)}원',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (order.deliveryFee > 0) ...[
                  SizedBox(height: healthDp(context, 5)),
                  Text(
                    '(배송비: ${PriceFormatter.format(order.deliveryFee)}원)',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
      if (!order.isPrescriptionOrder) {
        return _buildGeneralGroupedProductBlocks(order);
      }
      return _buildPrescriptionGroupedProductBlocks(order);
    }

    final qty = order.firstProductQty ?? 1;
    var qtyLine = '수량: $qty';
    final opt = order.firstProductOption;
    if (opt != null && opt.isNotEmpty) {
      qtyLine += 'ㅣ$opt';
    }

    return [
      _buildOrderProductLineInk(
        order,
        image: _buildProductImage(order),
        title: order.firstProductName ?? '상품명 없음',
        qtyLine: qtyLine,
        priceText: '${PriceFormatter.format(order.firstProductPrice ?? 0)}원',
        moreHint:
            order.odCartCount > 1 ? '외 ${order.odCartCount - 1}개 상품' : null,
      ),
    ];
  }

  List<Widget> _buildPrescriptionGroupedProductBlocks(OrderListModel order) {
    final groups = groupOrderItemsWithSupply(order.items);
    final widgets = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) widgets.add(SizedBox(height: healthDp(context, 16)));
      final group = groups[i];
      final parent = group.parent;
      final children = group.children;
      final showMoreHint = groups.length == 1 &&
          children.isEmpty &&
          order.odCartCount > 1;
      final key = '${order.odId}:${parent.ctId}';
      final expanded = _expandedSupplyKeys.contains(key);

      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderProductLineInk(
              order,
              image: _buildProductImageFromItem(parent),
              title: orderItemDisplayTitle(parent),
              qtyLine: orderItemQtyOptionLine(parent),
              priceText: '${PriceFormatter.format(parent.totalPrice)}원',
              moreHint:
                  showMoreHint ? '외 ${order.odCartCount - 1}개 상품' : null,
            ),
            if (children.isNotEmpty) ...[
              SizedBox(height: healthDp(context, 10)),
              _buildSupplyExpandChip(
                count: children.length,
                expanded: expanded,
                onTap: () {
                  setState(() {
                    if (expanded) {
                      _expandedSupplyKeys.remove(key);
                    } else {
                      _expandedSupplyKeys.add(key);
                    }
                  });
                },
              ),
              if (expanded) ...[
                SizedBox(height: healthDp(context, 10)),
                for (var ci = 0; ci < children.length; ci++) ...[
                  if (ci > 0) SizedBox(height: healthDp(context, 8)),
                  _buildOrderProductLineInk(
                    order,
                    image: _buildProductImageFromItem(children[ci]),
                    title: orderItemDisplayTitle(children[ci]),
                    qtyLine: orderItemQtyOptionLine(children[ci]),
                    priceText:
                        '${PriceFormatter.format(children[ci].totalPrice)}원',
                  ),
                ],
              ],
            ],
          ],
        ),
      );
    }
    return widgets;
  }

  Widget _buildSupplyExpandChip({
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 7),
          ),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1.11),
                color: const Color(0x3FFF5A8D),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: healthDp(context, 5),
                height: healthDp(context, 5),
                decoration: const BoxDecoration(
                  color: _kPink,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: healthDp(context, 6)),
              Text(
                '추가상품 $count개 포함',
                style: TextStyle(
                  color: _kPink,
                  fontSize: healthSp(context, 11),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                expanded ? '접기' : '펼치기',
                style: TextStyle(
                  color: _kPink,
                  fontSize: healthSp(context, 10),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: healthDp(context, 3)),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: healthSp(context, 14),
                color: _kPink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGeneralGroupedProductBlocks(OrderListModel order) {
    final groups = groupOrderItemsByItSubject(order.items);
    final widgets = <Widget>[];
    for (var gi = 0; gi < groups.length; gi++) {
      if (gi > 0) {
        widgets.add(SizedBox(height: healthDp(context, 10)));
        widgets.add(
          Container(
            width: double.infinity,
            height: 0.5,
            color: const Color(0x7FD2D2D2),
          ),
        );
        widgets.add(SizedBox(height: healthDp(context, 10)));
      }
      final subject = groups[gi].key;
      final items = groups[gi].value;
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.isNotEmpty) ...[
              Text(
                subject,
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: healthDp(context, 10)),
            ],
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: healthDp(context, 10)),
              _buildOrderProductLineInk(
                order,
                image: _buildProductImageFromItem(items[i]),
                title: orderItemDisplayTitle(items[i]),
                qtyLine: orderItemQtyOptionLine(items[i]),
                priceText: '${PriceFormatter.format(items[i].totalPrice)}원',
              ),
            ],
          ],
        ),
      );
    }
    return widgets;
  }

  /// 상품 행 — 주문번호와 동일하게 카드 좌측(패딩 20)에 맞춤
  Widget _buildOrderProductLineInk(
    OrderListModel order, {
    required Widget image,
    required String title,
    required String qtyLine,
    required String priceText,
    String? moreHint,
  }) {
    return InkWell(
      onTap: () => _navigateToOrderDetail(order),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image,
          SizedBox(width: healthDp(context, 10)),
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
                    letterSpacing: -0.90,
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

    final thumb = healthDp(context, 72);
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
              child: AppNetworkImage(
                url: normalizedUrl,
                width: thumb,
                height: thumb,
                decodeWidthLogical: thumb,
                decodeHeightLogical: thumb,
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

  /// 카드 하단 액션 / 안내
  Widget? _buildOrderCardActions(OrderListModel order) {
    final isPrescription = order.isPrescriptionOrder;

    if (_isCancelledStage(order)) {
      return _buildActionRow([
        (
          label: '재주문하기',
          onTap: () => _reorder(order),
          style: _CardActionStyle.outlinePink,
        ),
      ]);
    }

    if (_isConsultationDoneStage(order) || _isPreparingStage(order)) {
      // 비대면 상담완료: '상담완료 후' 접두 / 일반 배송준비중: 접두 없음
      return _buildPreparingLockedBanner(
        context,
        withConsultPrefix: _isConsultationDoneStage(order),
      );
    }

    if (_isCompletedStage(order)) {
      final actions = <({String label, VoidCallback? onTap, _CardActionStyle style})>[
        (
          label: '1:1 문의',
          onTap: () => _openInquiry(),
          style: _CardActionStyle.outlinePink,
        ),
        (
          label: '배송조회',
          onTap: () => _trackDelivery(order.odId),
          style: _CardActionStyle.outlinePink,
        ),
      ];
      if (_canWriteReview(order)) {
        actions.add((
          label: '리뷰쓰기',
          onTap: () => _writeReview(order.odId),
          style: _CardActionStyle.primary,
        ));
      } else {
        actions.add((
          label: '다시 담기',
          onTap: () => _reorder(order),
          style: _CardActionStyle.primary,
        ));
      }
      return _buildActionRow(actions);
    }

    if (_isDeliveringStage(order)) {
      return _buildActionRow([
        (
          label: '수령확인',
          onTap: () => _confirmPurchase(order.odId),
          style: _CardActionStyle.outlinePink,
        ),
        (
          label: '배송조회',
          onTap: () => _trackDelivery(order.odId),
          style: _CardActionStyle.primary,
        ),
      ]);
    }

    // 결제대기중 / 결제완료
    if (_isPaymentWaitingStage(order) || _isPaidStage(order)) {
      final specs = <({String label, VoidCallback? onTap, _CardActionStyle style})>[
        (
          label: '주문취소',
          onTap: () => _cancelOrder(order.odId),
          style: _CardActionStyle.outlineGray,
        ),
      ];
      if (isPrescription) {
        specs.add((
          label: '예약시간변경',
          onTap: () => _changeReservationTimeFromList(order.odId),
          style: _CardActionStyle.outlinePink,
        ));
      }
      specs.add((
        label: '배송지변경',
        onTap: () => _changeDeliveryAddress(order),
        style: _CardActionStyle.primary,
      ));
      return _buildActionRow(specs);
    }

    return null;
  }

  Widget _buildPreparingLockedBanner(
    BuildContext context, {
    required bool withConsultPrefix,
  }) {
    final message = withConsultPrefix
        ? '상담완료 후 배송준비중인 상태로\n배송지 변경 또는 취소가 어렵습니다.'
        : '배송준비중인 상태로\n배송지 변경 또는 취소가 어렵습니다.';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0x19FF5A8D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _kPink,
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.50,
        ),
      ),
    );
  }

  Widget _buildActionRow(
    List<({String label, VoidCallback? onTap, _CardActionStyle style})> specs,
  ) {
    if (specs.isEmpty) return const SizedBox.shrink();
    final gap = healthDp(context, 10);
    return Row(
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: _cardActionButton(
              label: specs[i].label,
              style: specs[i].style,
              onTap: specs[i].onTap,
            ),
          ),
        ],
      ],
    );
  }

  ({Color background, Color foreground, Color? border}) _colorsForStyle(
    _CardActionStyle style,
  ) {
    switch (style) {
      case _CardActionStyle.primary:
        return (background: _kPink, foreground: Colors.white, border: null);
      case _CardActionStyle.outlinePink:
        return (background: Colors.white, foreground: _kPink, border: _kPink);
      case _CardActionStyle.outlineGray:
        return (
          background: Colors.white,
          foreground: _kMuted,
          border: const Color(0xFFD2D2D2),
        );
    }
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

  Widget _cardActionButton({
    required String label,
    required _CardActionStyle style,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final colors = _colorsForStyle(style);
    final bg = enabled
        ? colors.background
        : colors.background.withValues(
            alpha: colors.background == Colors.white ? 1 : 0.45,
          );
    final fg = enabled
        ? colors.foreground
        : colors.foreground.withValues(alpha: 0.45);
    final borderColor = colors.border == null
        ? null
        : (enabled ? colors.border! : colors.border!.withValues(alpha: 0.35));
    final radius = BorderRadius.circular(healthDp(context, 50));

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: bg,
            shape: RoundedRectangleBorder(
              side: borderColor == null
                  ? BorderSide.none
                  : BorderSide(
                      width: healthDp(context, 1),
                      color: borderColor,
                    ),
              borderRadius: radius,
            ),
          ),
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
        return '결제완료';
      case 'delivering':
        return '배송중';
      case 'completed':
        return '배송완료';
      case 'cancelled':
        return '취소';
      default:
        return '주문';
    }
  }

  String _getOrderStatusText(OrderListModel order) {
    if (_isCancelledStage(order)) return '주문취소';
    if (_isCompletedStage(order)) return '배송완료';
    if (_isDeliveringStage(order)) return '배송중';
    if (_isConsultationDoneStage(order)) return '상담완료';
    if (_isPreparingStage(order)) return '배송준비중';
    if (_isPaidStage(order)) return '결제완료';
    if (_isPaymentWaitingStage(order)) return '결제대기중';
    final status = order.displayStatus.trim();
    return status.isEmpty ? '주문' : status;
  }

  bool _isPaymentWaitingStage(OrderListModel order) {
    return order.displayStatus == '결제대기중' || order.odStatus == '주문';
  }

  bool _isPaidStage(OrderListModel order) {
    if (_isPreparingStage(order) ||
        _isConsultationDoneStage(order) ||
        _isDeliveringStage(order) ||
        _isCompletedStage(order) ||
        _isCancelledStage(order)) {
      return false;
    }
    if (order.isPrescriptionOrder &&
        (order.odStatus == '입금' || order.odStatus == '준비')) {
      return true;
    }
    return order.displayStatus == '결제완료' || order.odStatus == '입금';
  }

  bool _isPreparingStage(OrderListModel order) {
    if (order.isPrescriptionOrder) return false;
    return order.displayStatus == '배송준비중' || order.odStatus == '준비';
  }

  bool _isConsultationDoneStage(OrderListModel order) {
    if (!order.isPrescriptionOrder) return false;
    if (_isDeliveringStage(order) ||
        _isCompletedStage(order) ||
        _isCancelledStage(order)) {
      return false;
    }
    if (order.isConsultationDone) return true;
    final display = order.displayStatus;
    return display == '상담완료' || display.contains('상담');
  }

  bool _isDeliveringStage(OrderListModel order) {
    return order.displayStatus == '배송중' || order.odStatus == '배송';
  }

  bool _isCompletedStage(OrderListModel order) {
    return order.displayStatus == '배송완료' || order.odStatus == '완료';
  }

  bool _isCancelledStage(OrderListModel order) {
    return order.displayStatus.contains('취소') ||
        order.odStatus.contains('취소') ||
        order.displayStatus == '주문 취소' ||
        order.displayStatus == '주문취소';
  }

  /// 주문 상세 화면으로 이동 (복귀 시 목록 갱신 — 수령확인/취소 반영)
  Future<void> _navigateToOrderDetail(OrderListModel order) async {
    await Navigator.pushNamed(
      context,
      '/order-detail',
      arguments: {
        'orderNumber': order.odId,
        'initialOrder': OrderDetailModel.fromListPreview(order),
      },
    );
    if (mounted) await _loadOrders();
  }

  Future<void> _openInquiry() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QaCategoryScreen()),
    );
  }

  Future<void> _reorder(OrderListModel order) async {
    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      AppToastOverlay.show(context, '로그인이 필요합니다.');
      return;
    }

    // 상세에서 옵션·수량 포함 상품 목록을 가져와 동일 구성으로 담기
    List<OrderItem> products = List<OrderItem>.from(order.items);
    try {
      final detailResult = await OrderService.getOrderDetail(
        odId: order.odId,
        mbId: user.id,
      );
      if (detailResult['success'] == true) {
        final detail = detailResult['order'] as OrderDetailModel;
        if (detail.products.isNotEmpty) {
          products = detail.products;
        }
      }
    } catch (_) {}

    if (products.isEmpty) {
      if (!mounted) return;
      AppToastOverlay.show(context, '재주문할 상품 정보를 찾을 수 없습니다.');
      return;
    }

    final defaultKind =
        order.isPrescriptionOrder ? 'prescription' : 'general';
    String? sharedOdId;

    for (final product in products) {
      if (product.itId.trim().isEmpty) continue;

      final qty = product.ctQty > 0 ? product.ctQty : 1;
      var kind =
          (product.ctKind ?? product.itKind ?? defaultKind).trim();
      if (kind.toLowerCase().startsWith('supply_add|')) {
        kind = defaultKind;
      }
      if (kind.isEmpty) kind = defaultKind;

      final price = product.ctPrice > 0
          ? product.ctPrice
          : (product.totalPrice > 0 ? product.totalPrice : 0);
      final optionText = (product.ctOption ?? '').trim();
      final optionId = (product.ioId ?? '').trim();
      final parentItId = (product.parent ?? '').trim();

      final result = await CartService.addToCart(
        productId: product.itId,
        quantity: qty,
        price: price,
        optionId: optionId.isEmpty ? null : optionId,
        optionText: optionText.isEmpty ? null : optionText,
        optionPrice: product.ioPrice,
        ioType: product.ioType,
        odId: sharedOdId,
        ctKind: kind,
        parentItId: parentItId.isEmpty ? null : parentItId,
        ctStatus: '쇼핑',
      );

      if (result['success'] != true) {
        if (!mounted) return;
        AppToastOverlay.show(
          context,
          result['message']?.toString() ?? '장바구니 담기에 실패했습니다.',
        );
        return;
      }

      final data = result['data'];
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        sharedOdId ??= (map['od_id'] ?? map['odId'])?.toString();
      }
    }

    if (!mounted) return;
    AppToastOverlay.show(context, '장바구니에 담았습니다.');
    await CartNavigation.openCart(
      context,
      prescriptionTab: order.isPrescriptionOrder,
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
      AppToastOverlay.show(
        context,
        result['message']?.toString() ?? '수령 확인되었습니다.',
      );
      await _loadOrders();
    } else {
      AppToastOverlay.show(
        context,
        result['message']?.toString() ?? '수령확인에 실패했습니다.',
      );
    }
  }

  /// 리뷰 쓰기
  Future<void> _writeReview(String odId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }
      final userId = user.id;

      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );

      if (result['success'] != true) {
        return;
      }

      final orderDetail = result['order'] as OrderDetailModel;
      final check = await ReviewService.checkReviewExists(
        mbId: userId,
        odId: odId,
      );
      final reviewed =
          (check['reviewedItIds'] as List<String>?) ?? const <String>[];
      final pending = pendingReviewProducts(orderDetail, reviewed);

      if (pending.isEmpty) {
        if (mounted) {
          AppToastOverlay.show(context, '작성할 리뷰가 없습니다.');
          setState(() {
            _reviewedItIdsByOd = {
              ..._reviewedItIdsByOd,
              odId: reviewed,
            };
          });
        }
        return;
      }

      if (!mounted) return;
      final isPrescription = orderDetail.isPrescriptionOrder;
      final bool? reviewWritten;
      if (pending.length > 1) {
        reviewWritten = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => DeliverySelectList(
              orderDetail: orderDetail,
              pendingProducts: pending,
            ),
          ),
        );
      } else {
        reviewWritten = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => isPrescription
                ? ReviewWriteScreen(
                    orderDetail: orderDetail,
                    selectedProducts: pending,
                  )
                : ReviewWriteGeneralScreen(
                    orderDetail: orderDetail,
                    selectedProducts: pending,
                  ),
          ),
        );
      }

      if (reviewWritten == true) {
        await _loadOrders();
      }
    } catch (e) {}
  }

  Future<void> _changeDeliveryAddress(OrderListModel order) async {
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
            DeliveryAddressChangePopup(
              orderId: order.odId,
              recipientName: order.recipientName,
              recipientPhone: order.recipientPhone,
              recipientAddress: order.recipientAddress,
              recipientAddressDetail: order.recipientAddressDetail,
            ),
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
    
    final thumb = healthDp(context, 72);
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
              child: AppNetworkImage(
                url: normalizedUrl,
                width: thumb,
                height: thumb,
                decodeWidthLogical: thumb,
                decodeHeightLogical: thumb,
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

