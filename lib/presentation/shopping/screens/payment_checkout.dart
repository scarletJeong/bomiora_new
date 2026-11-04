part of 'payment_screen.dart';

extension _PaymentCheckout on _PaymentScreenState {
  /// 운영 쇼핑몰 `www/shop/orderform.sub.payment.php` 의 `od_settle_case` 값과 동일.
  String get _paymentMethodLabel {
    switch (_paymentMethodIndex) {
      case 1:
        return '계좌이체';
      case 2:
        return '가상계좌';
      default:
        return '신용카드';
    }
  }


  /// KCP PayPlus hidden `pay_method` (영카트 `www/shop/orderform.sub.php` forderform_check 분기와 동일).
  String get _kcpPayMethodBits {
    switch (_paymentMethodIndex) {
      case 1:
        return '010000000000';
      case 2:
        return '001000000000';
      default:
        return '100000000000';
    }
  }

  String _kcpMobileUserAgent() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36';
  }

  String _kcpDesktopUserAgent() {
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
  }

  String _kcpRequestUserAgent({required bool mobile}) =>
      mobile ? _kcpMobileUserAgent() : _kcpDesktopUserAgent();


  /// 앱 패널(최대 650)은 모바일 KCP. 넓은 PC 창만 표준창.
  bool _useMobileKcpPay(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= 650;

  bool _validateBeforePay() {
    final receiverEmpty = _receiverController.text.trim().isEmpty;
    final phoneEmpty = _phoneController.text.trim().isEmpty;
    final zipEmpty = _zipController.text.trim().isEmpty;
    final addressEmpty = _addressController.text.trim().isEmpty;

    if (receiverEmpty) {
      AppToastOverlay.showAlert(context, '받는 분을 입력해 주세요.');
      return false;
    }
    if (phoneEmpty) {
      AppToastOverlay.showAlert(context, '연락처를 입력해 주세요.');
      return false;
    }
    if (zipEmpty || addressEmpty) {
      AppToastOverlay.showAlert(context, '배송지 주소를 검색해 주세요.');
      return false;
    }
    if (!_hasSavedAddress && _detailAddressController.text.trim().isEmpty) {
      AppToastOverlay.showAlert(context, '상세주소를 입력해 주세요.');
      return false;
    }
    if (_finalAmount < _minPayableAmount) {
      AppToastOverlay.showAlert(
        context,
        '최종 결제금액은 ${PriceFormatter.format(_minPayableAmount)}원 이상이어야 합니다.',
      );
      return false;
    }
    return true;
  }

  Future<void> _requestKcpPayment() async {
    if (_submitting) return;
    if (!_validateBeforePay()) return;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) {
      if (mounted) {
        AppToastOverlay.showAlert(context, '로그인 정보를 확인할 수 없습니다.');
      }
      return;
    }

    final cartIds = widget.cartItems.map((e) => e.ctId).toList();
    if (cartIds.isEmpty) {
      if (mounted) {
        AppToastOverlay.showAlert(context, '결제할 상품이 없습니다.');
      }
      return;
    }

    _setState(() {
      _submitting = true;
    });

    try {
      final useMobilePay = _useMobileKcpPay(context);
      Future<KcpPaySession> bootstrap() async {
        await _maybeSaveDefaultAddress(user.id);
        final quote = await _loadShippingQuote();
        final baseShipping = quote?.baseShipping ?? _baseShipping;
        final extraShipping = quote?.extraShipping ?? _extraShipping;
        final response = await ApiClient.post(
          ApiEndpoints.kcpPayRequest,
          {
            'mb_id': user.id,
            'cart_ids': cartIds,
            'payment_method': _paymentMethodLabel,
            'pay_method': _kcpPayMethodBits,
            'escrow_use': _useEscrow,
            'shipping_cost': baseShipping + extraShipping,
            'base_shipping_cost': baseShipping,
            'extra_shipping_cost': extraShipping,
            'coupon_discount':
                _productCouponDiscount + _shippingCouponDiscount,
            'cp_ids': _selectedCoupons
                .map((c) => c.id.trim())
                .where((id) => id.isNotEmpty)
                .toList(),
            'coupons': _checkoutCouponPayload(),
            'used_point': _pointDiscount,
            'final_amount': _finalAmount,
            'goods_name': widget.cartItems.length == 1
                ? widget.cartItems.first.itName
                : '${widget.cartItems.first.itName} 외 ${widget.cartItems.length - 1}건',
            'orderer': {
              'name': user.name,
              'email': user.email,
              'tel': user.phone ?? _phoneController.text.trim(),
              'hp': user.phone ?? _phoneController.text.trim(),
            },
            'od_memo': _deliveryRequestMemo,
            'receiver': {
              'name': _receiverController.text.trim(),
              'tel': _phoneController.text.trim(),
              'hp': _phoneController.text.trim(),
              'zip': _zipController.text.trim(),
              'addr1': _addressController.text.trim(),
              'addr2': _detailAddressController.text.trim(),
              'addr3': '',
              'memo': _deliveryRequestMemo,
            },
            'user_agent': useMobilePay
                ? (defaultTargetPlatform == TargetPlatform.iOS
                    ? 'iPhone'
                    : 'Android')
                : 'Windows',
            'is_mobile': useMobilePay,
            if (kIsWeb) 'return_url': '${Uri.base.origin}/',
          },
          additionalHeaders: <String, String>{
            'User-Agent': _kcpRequestUserAgent(mobile: useMobilePay),
          },
        );

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200 || data['success'] != true) {
          throw KcpPayStartException(
            (data['message'] ?? '결제 요청에 실패했습니다.').toString(),
            errorCode: (data['error_code'] ?? '').toString(),
          );
        }
        final html = (data['html'] ?? '').toString();
        final token = (data['token'] ?? '').toString();
        if (html.isEmpty || token.isEmpty) {
          throw KcpPayStartException('KCP 결제 요청 응답이 올바르지 않습니다.');
        }
        return KcpPaySession(html: html, token: token);
      }

      final payScreen = KcpPayWebViewScreen(
        usePcLayout: !useMobilePay,
        bootstrap: bootstrap(),
      );
      dynamic result;
      if (kIsWeb) {
        result = await Navigator.of(context).push<Map<String, dynamic>>(
          PageRouteBuilder(
            opaque: true,
            fullscreenDialog: true,
            pageBuilder: (context, animation, secondaryAnimation) {
              return payScreen;
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else {
        result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => payScreen),
        );
      }

      if (!mounted) return;
      if (result == null) {
        AppToastOverlay.showAlert(context, '결제가 완료되지 않았습니다.');
        return;
      }
      final resultMap = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      final success = resultMap['success'] == true;
      final message = (resultMap['message'] ?? '').toString();
      final errorCode = (resultMap['error_code'] ?? '').toString().trim();
      var orderId = (resultMap['order_id'] ?? '').toString().trim();
      final token = (resultMap['token'] ?? '').toString().trim();

      if (success) {
        clearKcpPayToken();
        // 가상계좌 등에서 order_id 누락 시 결과 API로 한 번 더 보정
        if (orderId.isEmpty && token.isNotEmpty) {
          try {
            final retry = await ApiClient.get(ApiEndpoints.kcpPayResult(token));
            if (retry.statusCode == 200) {
              final retryData = jsonDecode(retry.body) as Map<String, dynamic>;
              orderId = (retryData['order_id'] ?? '').toString().trim();
            }
          } catch (_) {}
        }

        if (!mounted) return;
        OrderService.invalidateOrderList();
        if (orderId.isNotEmpty) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/payment-complete',
            (route) => route.isFirst,
            arguments: {'orderId': orderId},
          );
        } else {
          // 성공인데 주문번호가 없으면 주문내역으로 (메인으로 떨어지지 않게)
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/order',
            (route) => route.isFirst,
          );
        }
      } else {
        final code = _resolvePaymentErrorCode(errorCode, message);
        if (code == 'STOCK') {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('결제할 수 없습니다'),
              content: Text(
                message.isNotEmpty
                    ? message
                    : '재고 또는 금액이 변경되었습니다. 장바구니를 확인해 주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          return;
        }
        if (code == '3001' || code == 'USER_CANCELLED') {
          AppToastOverlay.show(context, '결제가 완료되지 않았습니다.');
          return;
        }
        clearKcpPayToken();

        AppToastOverlay.show(
          context,
          message.isNotEmpty ? message : '결제가 완료되지 않았습니다.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message =
          e is KcpPayStartException ? e.message : '결제 요청 중 오류가 발생했습니다.';
      AppToastOverlay.showAlert(context, message);
    } finally {
      if (mounted) {
        _setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _resolvePaymentErrorCode(String rawCode, String message) {
    final code = rawCode.trim();
    if (code.isNotEmpty) return code;

    final match = RegExp(r'\[([A-Za-z0-9_]+)\]').firstMatch(message);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
    if (message.contains('NO_CODE')) return 'NO_CODE';
    return 'UNKNOWN';
  }
}
