import 'package:flutter/material.dart';
import 'dart:ui';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../core/logging/failure_log.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/load_failure_notice.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'delivery_list_reorder.dart';
import 'delivery_list_review.dart';
import 'delivery_list_tracking.dart';
import 'delivery_order_stage.dart';
import 'widgets/delivery_order_card.dart';
import 'widgets/delivery_status_filter_bar.dart';
import 'widgets/reservation_time_change_popup.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../core/constants/app_assets.dart';
import 'widgets/delivery_address_change_popup.dart';
import 'widgets/order_flow_dialogs.dart';
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

  /// 마이페이지 미리받기와 같은 크기. 취소 건을 거르고 10장을 채우려고 10건씩 여러 번 받지 않는다.
  static const int _fetchSize = 80;
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

  /// 주문 목록. 현재 탭에 보이는 주문이 [fillTo]건이 되거나 다음 페이지가 없을 때까지 10건씩 이어 받는다.
  Future<void> _loadOrders({
    bool force = false,
    bool append = false,
    int? fillTo,
  }) async {
    if (append) {
      if (_isLoading || _isLoadingMore || !_hasNext) return;
    } else if (_isLoading && !force) {
      return;
    }
    final gen = ++_ordersLoadGen;
    final targetCount = fillTo ?? (append ? _visibleCount + _pageSize : _pageSize);

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
      final orders = append
          ? List<OrderListModel>.from(_allOrders)
          : <OrderListModel>[];
      final reviewed = append
          ? Map<String, List<String>>.from(_reviewedItIdsByOd)
          : <String, List<String>>{};
      final seen = orders.map((order) => order.odId).toSet();
      var page = append ? _nextPage : 0;
      var hasNext = false;
      var guard = 0;

      while (guard < 30) {
        guard++;
        if (!mounted || gen != _ordersLoadGen) return;
        final result = await OrderService.getOrderList(
          mbId: userId,
          period: 0,
          status: 'all',
          page: page,
          size: _fetchSize,
          forceRefresh: force || append || page > 0,
        );
        if (gen != _ordersLoadGen) return;
        if (result['success'] != true) {
          if (orders.isEmpty) {
            await _reportOrderLoadFailure(
              gen: gen,
              mbId: userId,
              reason: result['message']?.toString() ?? '주문 목록 조회에 실패했습니다.',
            );
            return;
          }
          hasNext = true;
          break;
        }

        final pageOrders = _ordersFromResult(result['orders']);
        pageOrders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
        if (!mounted || gen != _ordersLoadGen) return;
        final pageReviewed = await _reviewedItIdsBeforePaint(
          userId,
          pageOrders,
          result['reviewedByOrder'],
        );
        if (!mounted || gen != _ordersLoadGen) return;
        orders.addAll(pageOrders.where((order) => seen.add(order.odId)));
        reviewed.addAll(pageReviewed);
        hasNext = _resultHasNext(result, pageOrders.length);
        page++;
        final filled = _filteredCount(orders) >= targetCount || !hasNext;
        if (!filled &&
            !append &&
            mounted &&
            gen == _ordersLoadGen &&
            _filteredCount(orders) > 0) {
          setState(() {
            final shown = List<OrderListModel>.from(orders)
              ..sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
            _allOrders = shown;
            _reviewedItIdsByOd = Map<String, List<String>>.from(reviewed);
            _nextPage = page;
            _hasNext = hasNext;
            _loadFailed = false;
            _isLoading = false;
            _isLoadingMore = true;
            _applyFilter();
          });
        }
        if (filled) break;
      }

      if (!mounted || gen != _ordersLoadGen) return;
      setState(() {
        orders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
        _allOrders = orders;
        _reviewedItIdsByOd = reviewed;
        _nextPage = page;
        _hasNext = hasNext;
        if (!append) _visibleCount = _pageSize;
        _loadFailed = false;
        _applyFilter();
      });
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
    if (fetchedCount > _fetchSize) return false;
    final totalPages = int.tryParse('${result['totalPages'] ?? ''}');
    final currentPage = int.tryParse('${result['currentPage'] ?? ''}');
    if (totalPages != null && totalPages > 0 && currentPage != null) {
      return currentPage + 1 < totalPages;
    }
    final totalItems = int.tryParse('${result['totalItems'] ?? ''}');
    if (totalItems != null && totalItems > 0 && currentPage != null) {
      return (currentPage + 1) * _fetchSize < totalItems;
    }
    if (result['hasNext'] == true) return true;
    return fetchedCount >= _fetchSize;
  }

  bool get _canLoadMore =>
      _displayedOrders.length > _visibleCount || _hasNext;

  List<OrderListModel> get _visibleOrders {
    if (_displayedOrders.length <= _visibleCount) return _displayedOrders;
    return _displayedOrders.take(_visibleCount).toList();
  }

  Future<void> _loadMoreOrders() async {
    final target = _visibleCount + _pageSize;
    if (_displayedOrders.length < target && _hasNext && !_isLoadingMore) {
      await _loadOrders(append: true, fillTo: target);
    }
    if (!mounted) return;
    setState(() => _visibleCount = target);
  }

  Future<void> _fillDisplayedTo(int count) async {
    if (_displayedOrders.length >= count || !_hasNext) return;
    if (_isLoading || _isLoadingMore) return;
    await _loadOrders(append: true, fillTo: count);
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

  /// 완료 주문의 리뷰 it_id. 목록이 주문마다 값을 주면 그 값을 쓰고, 빠졌을 때만 리뷰 API를 부른다.
  Future<Map<String, List<String>>> _reviewedItIdsBeforePaint(
    String mbId,
    List<OrderListModel> orders,
    dynamic rawFromList,
  ) async {
    final completedIds = orders
        .where(isOrderCompleted)
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
    // 목록 응답이 완료 주문마다 리뷰 it_id(없으면 빈 배열)를 주면 추가 조회를 하지 않는다.
    if (completedIds.every(fromList.containsKey)) return merged;

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


  /// 필터 적용
  void _applyFilter() {
    _displayedOrders = _allOrders.where(_matchesCurrentFilter).toList();
  }

  int _filteredCount(List<OrderListModel> orders) {
    return orders.where(_matchesCurrentFilter).length;
  }

  bool _matchesCurrentFilter(OrderListModel order) {
    final typeMatches = _selectedProductType == DeliveryProductType.prescription
        ? order.isPrescriptionOrder
        : !order.isPrescriptionOrder;
    if (!typeMatches) return false;
    if (_selectedStatus == 'all') {
      if (isOrderCancelled(order)) return false;
      if (isOrderCompleted(order)) return true;
      if (order.countsAsOpenOrderHistory) return true;
      return isOrderPaymentWaiting(order);
    }
    return _matchesStatusFilter(order);
  }

  bool _matchesStatusFilter(OrderListModel order) {
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
  }

  void _selectProductType(String productType) {
    if (_selectedProductType == productType) return;
    // 필터 UI는 바에서 먼저 반영되고, 목록 리빌드는 다음 프레임에 수행
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _selectedProductType == productType) return;
      setState(() {
        _selectedProductType = productType;
        _selectedStatus = 'all';
        _visibleCount = _pageSize;
        _applyFilter();
      });
      _scrollToTop();
      await _fillDisplayedTo(_pageSize);
    });
  }

  /// 상태 필터 선택
  void _selectStatus(String status) {
    if (_selectedStatus == status) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _selectedStatus == status) return;
      setState(() {
        _selectedStatus = status;
        _visibleCount = _pageSize;
        _applyFilter();
      });
      _scrollToTop();
      await _fillDisplayedTo(_pageSize);
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
                    child: _isLoadingMore
                        ? const Center(
                            child: CircularProgressIndicator(color: _kPink),
                          )
                        : _canLoadMore
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
                          return DeliveryOrderCard(
                            order: order,
                            expandedKeys: _expandedSupplyKeys,
                            onToggleSupply: _toggleSupply,
                            onOpenDetail: _navigateToOrderDetail,
                            onReorder: _reorder,
                            onInquiry: _openInquiry,
                            onTrackDelivery: _trackDelivery,
                            onWriteReview: _writeReview,
                            canWriteReview: _canWriteReview,
                            onConfirmPurchase: _confirmPurchase,
                            onChangeAddress: _changeDeliveryAddress,
                            onChangeReservation: _changeReservationTimeFromList,
                            onCancelOrder: _cancelOrderFromList,
                          );
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

  /// 결제대기중·결제완료 목록에서 주문 취소
  Future<void> _cancelOrderFromList(OrderListModel order) async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      AppToastOverlay.show(context, '로그인이 필요합니다.');
      return;
    }
    final ok = await OrderFlowDialogs.runOrderCancelFlow(
      context,
      odId: order.odId,
      mbId: user.id,
    );
    if (ok && mounted) {
      await OrderFlowDialogs.openCancelledOrderPage(
        context,
        odId: order.odId,
        isPrescription: order.isPrescriptionOrder,
      );
    }
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

  Future<void> _reorder(OrderListModel order) {
    return reorderFromOrderList(context, order);
  }

  Future<void> _trackDelivery(String odId) {
    return trackOrderDelivery(context, odId);
  }

  bool _canWriteReview(OrderListModel order) {
    return orderListCanWriteReview(
      order,
      _reviewedItIdsByOd[order.odId] ?? const <String>[],
    );
  }

  void _toggleSupply(String key) {
    setState(() {
      if (!_expandedSupplyKeys.add(key)) {
        _expandedSupplyKeys.remove(key);
      }
    });
  }


  Future<void> _writeReview(String odId) async {
    final result = await writeOrderListReview(context, odId);
    if (!mounted || result == null) return;
    final reviewed = result.reviewedIds;
    if (reviewed != null) {
      setState(() {
        _reviewedItIdsByOd = {
          ..._reviewedItIdsByOd,
          odId: reviewed,
        };
      });
    }
    if (result.reload) await _loadOrders(force: true);
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

