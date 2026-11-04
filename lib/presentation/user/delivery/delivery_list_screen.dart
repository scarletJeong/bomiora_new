import 'package:flutter/material.dart';
import 'dart:ui';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../core/logging/failure_log.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/load_failure_notice.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'widgets/delivery_status_filter_bar.dart';
import 'widgets/reservation_time_change_popup.dart';
import '../review/review_write_screen.dart';
import '../review/review_write_general_screen.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/order_cart_add.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../../core/navigation/app_action_gate.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../shopping/utils/cart_navigation.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../common/widgets/app_network_image.dart';
import 'widgets/delivery_address_change_popup.dart';
import 'widgets/delivery_select_list.dart';
import 'widgets/order_flow_dialogs.dart';
import 'widgets/order_item_subject_groups.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../customer_service/models/qa_inquiry_draft.dart';
import '../../customer_service/screens/qa_write_screen.dart';
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
  List<OrderListModel> _allOrders = []; // 지금까지 불러온 주문
  List<OrderListModel> _displayedOrders = []; // 화면에 표시할 주문 데이터
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  int _nextPage = 0;
  int _visibleCount = 10;
  bool _loggedOut = false;
  bool _loadFailed = false;
  static const String _loadFailMessage = '주문 내역을 불러오지 못했습니다.';
  int _ordersLoadGen = 0;
  static const int _pageSize = 10;
  String _selectedProductType = DeliveryProductType.prescription;
  String _selectedStatus = 'all';
  final ScrollController _scrollController = ScrollController();

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kInk = Color(0xFF1A1A1A);

  /// 주문상품 추가상품 펼침 키: `{odId}:{parentCtId}`
  final Set<String> _expandedSupplyKeys = {};

  /// 배송완료 주문의 이미 작성된 리뷰 itId `{ odId: [itId...] }`
  Map<String, List<String>> _reviewedItIdsByOd = {};

  String? _pendingOpenOdId;
  bool _routeArgsApplied = false;
  bool _productTypeFromRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _applyRouteArgs();
      await _loadOrders(
        force: _pendingOpenOdId != null || _productTypeFromRoute,
      );
      if (mounted) await _openPendingOrderDetail();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _applyRouteArgs() {
    if (_routeArgsApplied) return;
    _routeArgsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    final status = args['status']?.toString();
    final productType = args['productType']?.toString();
    final openOdId = args['openOdId']?.toString();
    if (productType == DeliveryProductType.general ||
        productType == DeliveryProductType.prescription) {
      _selectedProductType = productType!;
      _productTypeFromRoute = true;
    }
    if (status != null && status.isNotEmpty) {
      _selectedStatus = status;
    }
    if (openOdId != null && openOdId.isNotEmpty) {
      _pendingOpenOdId = openOdId;
    }
  }

  /// 주문 목록. 한 번에 10건만 받고, 더보기로 다음 페이지를 이어 붙인다.
  Future<void> _loadOrders({bool force = false, bool append = false}) async {
    if (append) {
      if (_isLoading || _isLoadingMore || !_hasNext) return;
    } else if (_isLoading && !force) {
      return;
    }
    final gen = ++_ordersLoadGen;
    final page = append ? _nextPage : 0;

    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _isLoadingMore = false;
      }
    });
    
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        setState(() {
          _loggedOut = true;
          _loadFailed = false;
          _allOrders = [];
          _displayedOrders = [];
          _hasNext = false;
          _nextPage = 0;
        });
        return;
      }
      _loggedOut = false;
      final userId = user.id;
      
      final result = await OrderService.getOrderList(
        mbId: userId,
        period: 0,
        status: 'all',
        page: page,
        size: _pageSize,
        forceRefresh: force || append,
      );
      
      if (result['success'] == true) {
        if (gen != _ordersLoadGen) return;
        final pageOrders = _ordersFromResult(result['orders']);
        pageOrders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));

        if (!mounted || gen != _ordersLoadGen) return;
        final reviewed = await _reviewedItIdsBeforePaint(
          userId,
          pageOrders,
          result['reviewedByOrder'],
        );
        if (!mounted || gen != _ordersLoadGen) return;
        setState(() {
          if (append) {
            final seen = _allOrders.map((order) => order.odId).toSet();
            _allOrders = [
              ..._allOrders,
              ...pageOrders.where((order) => seen.add(order.odId)),
            ];
            _reviewedItIdsByOd = {..._reviewedItIdsByOd, ...reviewed};
          } else {
            _allOrders = pageOrders;
            _reviewedItIdsByOd = reviewed;
          }
          _allOrders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
          _nextPage = page + 1;
          _hasNext = _resultHasNext(result, pageOrders.length);
          if (!append) _visibleCount = _pageSize;
          _loadFailed = false;
          _applyFilter();
        });
      } else if (gen == _ordersLoadGen) {
        await _reportOrderLoadFailure(
          gen: gen,
          mbId: userId,
          reason: result['message']?.toString() ?? '주문 목록 조회에 실패했습니다.',
        );
      }
    } catch (e) {
      await _reportOrderLoadFailure(
        gen: gen,
        mbId: AuthService.currentUser?.id ?? '',
        reason: e.toString(),
      );
    } finally {
      if (mounted && gen == _ordersLoadGen) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _reportOrderLoadFailure({
    required int gen,
    required String mbId,
    required String reason,
  }) async {
    await FailureLog.record(
      code: 'order.list',
      mbId: mbId,
      reason: reason,
    );
    if (!mounted || gen != _ordersLoadGen) return;
    final keepList = _allOrders.isNotEmpty;
    setState(() => _loadFailed = !keepList);
    if (keepList) {
      AppToastOverlay.showAlert(context, _loadFailMessage);
    }
  }

  List<OrderListModel> _ordersFromResult(dynamic ordersList) {
    if (ordersList is List<OrderListModel>) return List<OrderListModel>.from(ordersList);
    if (ordersList is! List) return [];
    return ordersList
        .whereType<Map>()
        .map((item) => OrderListModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  bool _resultHasNext(Map<String, dynamic> result, int fetchedCount) {
    if (fetchedCount > _pageSize) return false;
    final totalPages = int.tryParse('${result['totalPages'] ?? ''}');
    final currentPage = int.tryParse('${result['currentPage'] ?? ''}');
    if (totalPages != null && totalPages > 0 && currentPage != null) {
      return currentPage + 1 < totalPages;
    }
    final totalItems = int.tryParse('${result['totalItems'] ?? ''}');
    if (totalItems != null && totalItems > 0 && currentPage != null) {
      return (currentPage + 1) * _pageSize < totalItems;
    }
    if (result['hasNext'] == true) return true;
    return fetchedCount >= _pageSize;
  }

  bool get _canLoadMore =>
      _displayedOrders.length > _visibleCount || _hasNext;

  List<OrderListModel> get _visibleOrders {
    if (_displayedOrders.length <= _visibleCount) return _displayedOrders;
    return _displayedOrders.take(_visibleCount).toList();
  }

  Future<void> _loadMoreOrders() async {
    if (_displayedOrders.length > _visibleCount) {
      setState(() => _visibleCount += _pageSize);
      return;
    }
    if (!_hasNext || _isLoadingMore) return;
    final before = _allOrders.length;
    await _loadOrders(append: true);
    if (!mounted || _allOrders.length <= before) return;
    setState(() => _visibleCount += _pageSize);
  }

  List<String> _stringIds(dynamic value) {
    final list = <String>[];
    if (value is List) {
      for (final id in value) {
        final s = id?.toString().trim() ?? '';
        if (s.isNotEmpty) list.add(s);
      }
    }
    return list;
  }

  Map<String, List<String>> _reviewedMapFromRaw(dynamic raw) {
    final map = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final odId = key.toString().trim();
        if (odId.isEmpty) return;
        map[odId] = _stringIds(value);
      });
    }
    return map;
  }

  /// 카드를 그리기 전에 완료 주문의 리뷰 작성 it_id를 확정한다.
  /// 목록 응답만 보면 리뷰가 있는 주문도 리뷰쓰기로 먼저 그려진다.
  Future<Map<String, List<String>>> _reviewedItIdsBeforePaint(
    String mbId,
    List<OrderListModel> orders,
    dynamic rawFromList,
  ) async {
    final completedIds = orders
        .where(_isCompletedStage)
        .map((order) => order.odId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final fromList = _reviewedMapFromRaw(rawFromList);
    final merged = <String, List<String>>{
      for (final id in completedIds)
        id: List<String>.from(fromList[id] ?? const <String>[]),
    };
    if (completedIds.isEmpty) return merged;

    final requested = completedIds.toSet();
    final fetched = await ReviewService.getReviewedItIdsByOrders(
      mbId: mbId,
      odIds: completedIds,
    );
    final coversAll = completedIds.every(fetched.containsKey);
    final strayKey = fetched.keys.any((key) => !requested.contains(key));
    if (coversAll && !strayKey) {
      for (final id in completedIds) {
        merged[id] = _unionIds(merged[id], fetched[id]);
      }
      return merged;
    }

    final checks = await Future.wait(completedIds.map((odId) async {
      final check = await ReviewService.checkReviewExists(
        mbId: mbId,
        odId: odId,
      );
      return MapEntry(odId, _stringIds(check['reviewedItIds']));
    }));
    for (final entry in checks) {
      merged[entry.key] = _unionIds(merged[entry.key], entry.value);
    }
    return merged;
  }

  List<String> _unionIds(List<String>? a, List<String>? b) {
    final out = <String>[];
    for (final id in [...?a, ...?b]) {
      final s = id.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    return out;
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
      _displayedOrders = byType.where((order) {
        if (_isCancelledStage(order)) return false;
        if (_isCompletedStage(order)) return true;
        if (order.countsAsOpenOrderHistory) return true;
        return _isPaymentWaitingStage(order);
      }).toList();
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
    // 필터 UI는 바에서 먼저 반영되고, 목록 리빌드는 다음 프레임에 수행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedProductType == productType) return;
      setState(() {
        _selectedProductType = productType;
        _selectedStatus = 'all';
        _visibleCount = _pageSize;
        _applyFilter();
      });
      _scrollToTop();
    });
  }

  /// 상태 필터 선택
  void _selectStatus(String status) {
    if (_selectedStatus == status) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedStatus == status) return;
      setState(() {
        _selectedStatus = status;
        _visibleCount = _pageSize;
        _applyFilter();
      });
      _scrollToTop();
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
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
    if (_loggedOut && !_isLoading) {
      return _buildEmptyStateContent();
    }
    // 필터를 스크롤 밖에 두면 세로 스크롤과 탭/칩 제스처가 경쟁하지 않음
    final showLoadFailure = !_isLoading &&
        !_isLoadingMore &&
        _loadFailed &&
        _allOrders.isEmpty;
    final showEmpty = !_isLoading &&
        !_isLoadingMore &&
        !_loadFailed &&
        _displayedOrders.isEmpty &&
        !_hasNext;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeliveryStatusFilterBar(
          selectedProductType: _selectedProductType,
          onProductTypeSelected: _selectProductType,
          selectedKey: _selectedStatus,
          onSelected: _selectStatus,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadOrders(force: true),
            color: _kPink,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
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
                    child: _canLoadMore
                        ? Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 27),
                            ),
                            child: Center(child: _buildMoreButton()),
                          )
                        : const SizedBox.shrink(),
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
                          final order = _visibleOrders[index];
                          return _buildOrderCard(order);
                        },
                        childCount: _visibleOrders.length,
                      ),
                    ),
                  ),
                if (!_isLoading && _visibleOrders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        healthDp(context, 27),
                        0,
                        healthDp(context, 27),
                        healthDp(context, 48),
                      ),
                      child: _canLoadMore || _isLoadingMore
                          ? _buildMoreButton()
                          : SizedBox(height: healthDp(context, 8)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
        ),
        if (showLoadFailure)
          PageCenteredEmptyOverlay(
            child: LoadFailureNotice(
              message: _loadFailMessage,
              onRetry: () => _loadOrders(force: true),
            ),
          ),
        if (showEmpty)
          PageCenteredEmptyOverlay(child: _buildEmptyStateContent()),
      ],
    );
  }

  Widget _buildMoreButton() {
    if (!_canLoadMore && !_isLoadingMore) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 8)),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
        child: InkWell(
          onTap: _isLoadingMore ? null : _loadMoreOrders,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: SizedBox(
            width: double.infinity,
            height: healthDp(context, 40),
            child: Center(
              child: _isLoadingMore
                  ? SizedBox(
                      width: healthDp(context, 18),
                      height: healthDp(context, 18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPink,
                      ),
                    )
                  : Text(
                      '더보기',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 14),
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
                          '주문일자: ${DateDisplayFormatter.formatOrderDateTime(order.orderDate, withTime: false)}',
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
                        if (_scheduleLine(order) != null) ...[
                          SizedBox(height: healthDp(context, 5)),
                          Text(
                            _scheduleLine(order)!,
                            style: TextStyle(
                              color: _kPink,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => AppActionGate.protect(
                  () => _navigateToOrderDetail(order),
                ),
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
    final opt = ProductOption.visibleLabel(
      ctOption: order.firstProductOption,
    );
    if (opt.isNotEmpty) {
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
      onTap: () => AppActionGate.protect(() => _navigateToOrderDetail(order)),
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
                    color: _kMuted,
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
                        color: _kMuted,
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

    if (_isConsultationDoneStage(order)) {
      return _buildPreparingLockedBanner(
        context,
        withConsultPrefix: true,
      );
    }

    if (_isPreparingStage(order)) {
      return _buildActionRow([
        (
          label: '배송지변경',
          onTap: () => _changeDeliveryAddress(order),
          style: _CardActionStyle.primary,
        ),
      ]);
    }

    if (_isCompletedStage(order)) {
      final actions = <({String label, Future<void> Function()? onTap, _CardActionStyle style})>[
        (
          label: '1:1 문의',
          onTap: () => _openInquiry(order),
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

    // 결제대기중: 예약시간 변경과 주문취소 버튼은 숨긴다.
    if (_isPaymentWaitingStage(order)) {
      return _buildActionRow([
        (
          label: '배송지변경',
          onTap: () => _changeDeliveryAddress(order),
          style: _CardActionStyle.primary,
        ),
      ]);
    }

    if (_isPaidStage(order)) {
      final specs = <({String label, Future<void> Function()? onTap, _CardActionStyle style})>[];
      if (isPrescription) {
        specs.add((
          label: '예약시간변경',
          onTap: () => _changeReservationTimeFromList(order),
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
    List<({String label, Future<void> Function()? onTap, _CardActionStyle style})> specs,
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
    Future<void> Function()? onTap,
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
        onTap: onTap == null ? null : () => AppActionGate.protect(onTap),
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
    if (_loggedOut) {
      return CenteredEmptyState(
        iconWidget: CenteredEmptyState.assetIcon(
          context,
          AppAssets.emptyDeliveryIcon,
        ),
        message: '로그인 후 이용 가능합니다.',
        trailing: CenteredEmptyState.loginButtonTrailing(
          context,
          onPressed: () async {
            await Navigator.pushNamed(context, '/login');
            if (!mounted) return;
            await _loadOrders(force: true);
          },
        ),
      );
    }
    final statusText = _selectedStatus == 'all'
        ? '주문'
        : _getStatusText(_selectedStatus);
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyDeliveryIcon,
      ),
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

  String? _scheduleLine(OrderListModel order) {
    if (_isPaymentWaitingStage(order)) {
      final deadline =
          DateDisplayFormatter.formatBankDeadlineList(order.odBankAccount);
      if (deadline.isEmpty) return null;
      return '입금기간: $deadline';
    }
    if (!order.isPrescriptionOrder) return null;
    final reservation = _reservationLine(order);
    if (reservation.isEmpty) return null;
    return '예약시간: $reservation';
  }

  String _reservationLine(OrderListModel order) {
    if (_isCancelledStage(order)) return '';
    final dateLabel = _formatReservationDate(order.reservationDate);
    final timeLabel = _formatReservationTimeRange(
      order.reservationTime,
      order.reservationEndTime,
    );
    if (dateLabel.isEmpty && timeLabel.isEmpty) return '';
    if (dateLabel.isEmpty) return timeLabel;
    if (timeLabel.isEmpty) return dateLabel;
    return '$dateLabel $timeLabel';
  }

  String _formatReservationDate(String? raw) {
    final d = DateDisplayFormatter.tryParseYmdFlexible(raw);
    if (d == null) return '';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm.$dd(${weekdays[d.weekday - 1]})';
  }

  String _formatReservationTimeRange(String? start, String? end) {
    final st = start?.trim() ?? '';
    final et = end?.trim() ?? '';
    if (st.isNotEmpty && et.isNotEmpty) return '$st-$et';
    if (st.isNotEmpty) return st;
    return et;
  }

  /// 주문 상세 화면으로 이동 (복귀 시 목록 갱신 — 수령확인/취소 반영)
  Future<void> _navigateToOrderDetail(OrderListModel order) async {
    final odId = order.odId.trim();
    final result = await Navigator.pushNamed(
      context,
      '/order-detail/$odId',
      arguments: {
        'orderNumber': odId,
        'initialOrder': OrderDetailModel.fromListPreview(order),
      },
    );
    if (!mounted) return;
    if (result is Map && result['cancelled'] == true) {
      await _goToCancelledOrder(result['odId']?.toString() ?? order.odId);
      return;
    }
    await _loadOrders(force: true);
  }

  Future<void> _openPendingOrderDetail() async {
    final odId = _pendingOpenOdId;
    if (odId == null || odId.isEmpty) return;
    _pendingOpenOdId = null;
    await _openOrderDetailById(odId);
  }

  Future<void> _openOrderDetailById(String odId) async {
    OrderListModel? match;
    for (final o in _allOrders) {
      if (o.odId == odId) {
        match = o;
        break;
      }
    }
    if (!mounted) return;
    if (match != null) {
      await _navigateToOrderDetail(match);
      return;
    }
    final result = await Navigator.pushNamed(
      context,
      '/order-detail/${odId.trim()}',
      arguments: {'orderNumber': odId.trim()},
    );
    if (!mounted) return;
    if (result is Map && result['cancelled'] == true) {
      await _goToCancelledOrder(result['odId']?.toString() ?? odId);
      return;
    }
    await _loadOrders(force: true);
  }

  Future<void> _goToCancelledOrder(String odId) async {
    if (!mounted) return;
    _pendingOpenOdId = odId;
    setState(() => _selectedStatus = 'cancelled');
    await _loadOrders(force: true);
    if (mounted) await _openPendingOrderDetail();
  }

  Future<void> _openInquiry(OrderListModel order) async {
    var draft = QaInquiryDraft.fromOrderList(order);
    // 목록에 상품이 일부만 있으면 상세를 조회해 주문 전체 상품을 담는다
    final needDetail = order.items.length <= 1 && order.odCartCount > 1;
    if (needDetail || order.items.isEmpty) {
      try {
        final user = await AuthService.getUser();
        if (user != null) {
          final detailResult = await OrderService.getOrderDetail(
            odId: order.odId,
            mbId: user.id,
          );
          if (detailResult['success'] == true) {
            final detail = detailResult['order'] as OrderDetailModel;
            if (detail.products.isNotEmpty) {
              draft = QaInquiryDraft.fromOrderDetail(detail);
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QaWriteScreen(
          prefilledDraft: draft,
        ),
      ),
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

    final added = await OrderCartAdd.addProducts(
      products: products,
      prescription: order.isPrescriptionOrder,
    );
    if (!mounted) return;
    if (!_showReorderResult(added)) return;
    await CartNavigation.openCart(
      context,
      prescriptionTab: order.isPrescriptionOrder,
    );
  }

  bool _showReorderResult(OrderCartAddResult result) {
    switch (result.status) {
      case OrderCartAddStatus.needsLogin:
        AppToastOverlay.show(context, '로그인이 필요합니다.');
        return false;
      case OrderCartAddStatus.failed:
        AppToastOverlay.show(context, '장바구니 담기에 실패했습니다.');
        return false;
      case OrderCartAddStatus.partialLeft:
        AppToastOverlay.show(context, '일부 상품이 장바구니에 남아 있습니다.');
        return false;
      case OrderCartAddStatus.success:
        AppToastOverlay.show(context, '장바구니에 담았습니다.');
        return true;
    }
  }

  /// 배송 조회
  Future<void> _trackDelivery(String odId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        await _notifyTrackingFailure(odId, '로그인 정보가 없습니다.');
        return;
      }

      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );
      if (result['success'] != true) {
        await _notifyTrackingFailure(
          odId,
          result['message']?.toString() ?? '주문 정보를 불러오지 못했습니다.',
          mbId: user.id,
        );
        return;
      }

      final orderDetail = result['order'] as OrderDetailModel;
      final opened = await _openCourierTracking(
        odId: odId,
        mbId: user.id,
        companyName: orderDetail.deliveryCompany,
        trackingNumber: orderDetail.trackingNumber,
      );
      if (!opened) return;
    } catch (e) {
      await _notifyTrackingFailure(odId, e.toString());
    }
  }

  Future<bool> _openCourierTracking({
    required String odId,
    required String mbId,
    required String? companyName,
    required String? trackingNumber,
  }) async {
    final company = companyName?.trim() ?? '';
    final tracking = trackingNumber?.trim() ?? '';
    if (company.isEmpty) {
      await _notifyTrackingFailure(odId, '택배사 정보가 없습니다.', mbId: mbId);
      return false;
    }
    if (tracking.isEmpty) {
      await _notifyTrackingFailure(
        odId,
        '운송장 번호가 없습니다.',
        mbId: mbId,
        company: company,
      );
      return false;
    }
    if (!DeliveryTracker.isSupported(company)) {
      await _notifyTrackingFailure(
        odId,
        '지원하지 않는 택배사입니다.',
        mbId: mbId,
        company: company,
      );
      return false;
    }
    final opened = await DeliveryTracker.openTrackingPage(company, tracking);
    if (!opened) {
      await _notifyTrackingFailure(
        odId,
        '배송 조회 페이지를 열지 못했습니다.',
        mbId: mbId,
        company: company,
      );
    }
    return opened;
  }

  Future<void> _notifyTrackingFailure(
    String odId,
    String reason, {
    String? mbId,
    String? company,
  }) async {
    await FailureLog.record(
      code: 'order.tracking',
      mbId: mbId ?? AuthService.currentUser?.id ?? '',
      reason: reason,
      detail: {
        'odId': odId,
        if (company != null && company.isNotEmpty) 'company': company,
      },
    );
    if (!mounted) return;
    AppToastOverlay.show(context, '배송 조회를 실패했습니다.');
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
        '수령 확인되었습니다.',
      );
      await _loadOrders(force: true);
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
      final products = reviewableOrderProducts(orderDetail);
      var existing = ReviewService.reviewsOf(check);
      if (existing.isEmpty && reviewed.isNotEmpty) {
        existing = await ReviewService.reviewsForOrder(
          mbId: userId,
          odId: odId,
        );
      }

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
      final bool? reviewWritten = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => isPrescription
              ? ReviewWriteScreen(
                  orderDetail: orderDetail,
                  selectedProducts: products,
                  reviewedItIds: reviewed,
                  existingReviews: existing,
                )
              : ReviewWriteGeneralScreen(
                  orderDetail: orderDetail,
                  selectedProducts: products,
                  reviewedItIds: reviewed,
                  existingReviews: existing,
                ),
        ),
      );

      if (reviewWritten == true) {
        await _loadOrders(force: true);
      }
    } catch (e) {}
  }

  void _patchOrder(String odId, OrderListModel Function(OrderListModel) update) {
    setState(() {
      _allOrders = [
        for (final order in _allOrders)
          if (order.odId == odId) update(order) else order,
      ];
      _applyFilter();
    });
  }

  Future<void> _changeDeliveryAddress(OrderListModel order) async {
    final result = await showGeneralDialog<Object>(
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
    if (!mounted || result == null || result == false) return;
    if (result is Map) {
      _patchOrder(
        order.odId,
        (current) => current.copyWith(
          recipientName: (result['recipientName'] ?? '').toString(),
          recipientPhone: (result['recipientPhone'] ?? '').toString(),
          recipientAddress: (result['recipientAddress'] ?? '').toString(),
          recipientAddressDetail:
              (result['recipientAddressDetail'] ?? '').toString(),
        ),
      );
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

  /// 예약 시간 변경 — 목록에 있는 예약정보로 팝업만 열고, 저장 후 해당 카드만 갱신
  Future<void> _changeReservationTimeFromList(OrderListModel order) async {
    var date = (order.reservationDate ?? '').trim();
    var time = (order.reservationTime ?? '').trim();
    if (date.isEmpty || time.isEmpty) {
      final user = await AuthService.getUser();
      if (user == null) return;
      final result = await OrderService.getOrderDetail(
        odId: order.odId,
        mbId: user.id,
      );
      if (result['success'] != true) return;
      final detail = result['order'] as OrderDetailModel;
      date = (detail.reservationDate ?? '').trim();
      time = (detail.reservationTime ?? '').trim();
    }
    if (date.isEmpty || time.isEmpty || !mounted) return;

    final changeResult = await showGeneralDialog<ReservationPickResult?>(
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
              orderId: order.odId,
              currentDate: date,
              currentTime: time,
            ),
          ],
        );
      },
    );
    if (!mounted || changeResult is! ReservationPickResult) return;
    final picked = changeResult;
    final day =
        '${picked.date.year}-${picked.date.month.toString().padLeft(2, '0')}-${picked.date.day.toString().padLeft(2, '0')}';
    _patchOrder(
      order.odId,
      (current) => current.copyWith(
        reservationDate: day,
        reservationTime: picked.time,
        reservationEndTime: picked.endTime,
      ),
    );
  }
}

