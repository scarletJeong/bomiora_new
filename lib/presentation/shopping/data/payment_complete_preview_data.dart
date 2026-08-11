import '../../../data/models/delivery/delivery_model.dart';

/// 주문 완료 화면 UI 확인용 샘플 데이터.
///
/// ## 확인 URL / 진입
/// - 라우트: `/payment-complete`
/// - 인자 예: `Navigator.pushNamed(context, '/payment-complete', arguments: {'orderId': 'preview'});`
/// - [shouldUsePreview]가 true일 때 아래 샘플이 로드됩니다.
///
/// ## 사용법
/// - [enabled]: false 로 두면 이 파일은 사용되지 않습니다.
/// - [forcePreview]: true 이면 orderId와 관계없이 항상 샘플 데이터 표시 (UI 확인 후 false 권장).
/// - [previewMode]로 확인할 결제 유형을 선택합니다.
///   - 추가상품 포함: `*WithSupply` 모드 사용
enum PaymentCompletePreviewMode {
  /// 비대면 — 가상계좌 입금 대기
  virtualAccountPending,

  /// 비대면 — 가상계좌 입금 완료
  virtualAccountPaid,

  /// 비대면 — 신용카드
  creditCard,

  /// 비대면 — 계좌이체
  bankTransfer,

  /// 비대면 — 가상계좌 입금 완료 + 추가상품
  virtualAccountPaidWithSupply,

  /// 비대면 — 신용카드 + 추가상품
  creditCardWithSupply,

  /// 일반제품 — 신용카드
  generalCreditCard,

  /// 일반제품 — 가상계좌 입금 대기
  generalVirtualAccountPending,

  /// 일반제품 — 가상계좌 입금 완료
  generalVirtualAccountPaid,

  /// 일반제품 — 계좌이체
  generalBankTransfer,
}

class PaymentCompletePreviewData {
  PaymentCompletePreviewData._();

  static const bool enabled = true;
  /// UI 확인 시에만 true. 실결제 데이터 확인 시에는 반드시 false.
  static const bool forcePreview = false;
  static const String previewOrderId = 'preview';

  /// UI 확인 모드
  /// 추가상품 UI: [PaymentCompletePreviewMode.virtualAccountPaidWithSupply]
  static const PaymentCompletePreviewMode previewMode =
      PaymentCompletePreviewMode.virtualAccountPending;

  static bool shouldUsePreview(String orderId) {
    if (!enabled) return false;
    if (forcePreview) return true;
    final id = orderId.trim();
    return id.isEmpty || id == previewOrderId;
  }

  static OrderDetailModel get previewOrder {
    switch (previewMode) {
      case PaymentCompletePreviewMode.virtualAccountPending:
        return sampleVirtualAccountPendingOrder;
      case PaymentCompletePreviewMode.virtualAccountPaid:
        return sampleVirtualAccountPaidOrder;
      case PaymentCompletePreviewMode.creditCard:
        return sampleCreditCardOrder;
      case PaymentCompletePreviewMode.bankTransfer:
        return sampleBankTransferOrder;
      case PaymentCompletePreviewMode.virtualAccountPaidWithSupply:
        return sampleVirtualAccountPaidWithSupplyOrder;
      case PaymentCompletePreviewMode.creditCardWithSupply:
        return sampleCreditCardWithSupplyOrder;
      case PaymentCompletePreviewMode.generalCreditCard:
        return sampleGeneralCreditCardOrder;
      case PaymentCompletePreviewMode.generalVirtualAccountPending:
        return sampleGeneralVirtualAccountPendingOrder;
      case PaymentCompletePreviewMode.generalVirtualAccountPaid:
        return sampleGeneralVirtualAccountPaidOrder;
      case PaymentCompletePreviewMode.generalBankTransfer:
        return sampleGeneralBankTransferOrder;
    }
  }

  static const String _rxOption = '스페셜 ㅣ 3일(6포)';

  static List<OrderItem> get _rxProducts => [
        OrderItem(
          ctId: 1,
          itId: 'preview-item-1',
          itName: '보미 다이어트환 체험분',
          itSubject: '보미 다이어트환 체험분',
          ctOption: _rxOption,
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          itKind: 'prescription',
        ),
        OrderItem(
          ctId: 2,
          itId: 'preview-item-2',
          itName: '보미 디톡스환 체험분',
          itSubject: '보미 디톡스환 체험분',
          ctOption: '디톡스 ㅣ 15일(30포)',
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          itKind: 'prescription',
        ),
      ];

  /// 본품 1 + 추가상품 3 (parent = 본품 it_id)
  static List<OrderItem> get _rxProductsWithSupply => [
        OrderItem(
          ctId: 10,
          itId: 'preview-diet-1',
          itName: '보미 다이어트환 체험분',
          itSubject: '보미 다이어트환 체험분',
          ctOption: _rxOption,
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          itKind: 'prescription',
        ),
        OrderItem(
          ctId: 11,
          itId: 'preview-detox-a',
          itName: '보미 디톡스환 1단계',
          itSubject: '보미 디톡스환',
          ctOption: '디톡스 ㅣ 1개월',
          ctQty: 1,
          ctPrice: 12000,
          ioPrice: 0,
          totalPrice: 12000,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          parent: 'preview-diet-1',
          itKind: 'prescription',
        ),
        OrderItem(
          ctId: 12,
          itId: 'preview-detox-b',
          itName: '보미 디톡스환 2단계',
          itSubject: '보미 디톡스환',
          ctOption: '디톡스 ㅣ 1개월',
          ctQty: 1,
          ctPrice: 12000,
          ioPrice: 0,
          totalPrice: 12000,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          parent: 'preview-diet-1',
          itKind: 'prescription',
        ),
        OrderItem(
          ctId: 13,
          itId: 'preview-detox-c',
          itName: '보미 디톡스환 3단계',
          itSubject: '보미 디톡스환',
          ctOption: '디톡스 ㅣ 15일',
          ctQty: 1,
          ctPrice: 9000,
          ioPrice: 0,
          totalPrice: 9000,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          parent: 'preview-diet-1',
          itKind: 'prescription',
        ),
        OrderItem(
          ctId: 20,
          itId: 'preview-diet-2',
          itName: '보미 다이어트환 2단계',
          itSubject: '보미 다이어트환',
          ctOption: '소프트 ㅣ 1개월',
          ctQty: 1,
          ctPrice: 168000,
          ioPrice: 0,
          totalPrice: 168000,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'prescription',
          itKind: 'prescription',
        ),
      ];

  static List<OrderItem> get _generalProducts => [
        OrderItem(
          ctId: 1,
          itId: 'preview-general-1',
          itName: '보미 단백질 쉐이크 2종 골라담기',
          itSubject: '보미오라 한의원',
          ctOption: '초코ㅣ2주플랜(-10%)',
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'general',
          itKind: 'general',
        ),
        OrderItem(
          ctId: 2,
          itId: 'preview-general-2',
          itName: '보미 단백질 쉐이크 2종 골라담기',
          itSubject: '보미오라 한의원',
          ctOption: '초코ㅣ2주플랜(-10%)',
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'general',
          itKind: 'general',
        ),
        OrderItem(
          ctId: 3,
          itId: 'preview-general-3',
          itName: '액티브 탈모완호 샴푸 500ml 닥터스칼프',
          itSubject: '닥터스칼프',
          ctOption: '',
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'general',
          itKind: 'general',
        ),
        OrderItem(
          ctId: 4,
          itId: 'preview-general-4',
          itName: '액티브 탈모완호 샴푸 500ml 닥터스칼프',
          itSubject: '닥터스칼프',
          ctOption: '',
          ctQty: 1,
          ctPrice: 23900,
          ioPrice: 0,
          totalPrice: 23900,
          imageUrl: 'https://placehold.co/72x72',
          ctKind: 'general',
          itKind: 'general',
        ),
      ];

  static OrderDetailModel _base({
    required String paymentMethod,
    required String displayStatus,
    required String odStatus,
    required List<OrderItem> products,
    required bool isPrescription,
    String? paymentMethodDetail,
    String? odBankAccount,
    String? odAppNo,
    String orderDate = '2025.02.20',
    String? reservationDate,
    String? reservationTime,
    String? reservationEndTime,
    int? productPriceOverride,
    int? totalPriceOverride,
  }) {
    final productSum = products.fold<int>(0, (s, p) => s + p.totalPrice);
    return OrderDetailModel(
      odId: previewOrderId,
      orderDate: orderDate,
      displayStatus: displayStatus,
      odStatus: odStatus,
      recipientName: '김보미',
      recipientPhone: '01012345678',
      recipientAddress: '서울 송파구 올림픽로 300 (신천동, 시그니엘)',
      recipientAddressDetail: '101층',
      deliveryMessage: '부재시 경비실에 맡겨 주세요',
      products: products,
      productPrice: productPriceOverride ??
          (isPrescription ? productSum : 60000),
      deliveryFee: isPrescription ? 0 : 3000,
      discountAmount: 4800,
      couponDiscount: 1000,
      pointDiscount: 3800,
      totalPrice: totalPriceOverride ??
          (isPrescription ? (productSum - 4800).clamp(0, 1 << 31) : 56200),
      paymentMethod: paymentMethod,
      paymentMethodDetail: paymentMethodDetail,
      odBankAccount: odBankAccount,
      odAppNo: odAppNo,
      ordererName: '김보미',
      ordererPhone: '01012345678',
      ordererEmail: 'preview@bomiora.com',
      isPrescriptionOrder: isPrescription,
      reservationDate: reservationDate,
      reservationTime: reservationTime,
      reservationEndTime: reservationEndTime,
    );
  }

  static OrderDetailModel get sampleVirtualAccountPendingOrder => _base(
        paymentMethod: '가상계좌',
        displayStatus: '입금대기',
        odStatus: 'pending',
        products: _rxProducts,
        isPrescription: true,
        paymentMethodDetail: '(KEB하나은행)',
        odBankAccount: 'KEB하나은행/13396139137937/20250612235900/(주)세린헬스',
        orderDate: '2025.06.04',
        reservationDate: '2025-06-11',
        reservationTime: '14:30',
        reservationEndTime: '15:00',
      );

  static OrderDetailModel get sampleVirtualAccountPaidOrder => _base(
        paymentMethod: '가상계좌',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _rxProducts,
        isPrescription: true,
        paymentMethodDetail: '(KEB하나은행)',
        odBankAccount: 'KEB하나은행/13396139137937/20250612235900/보미오라',
        reservationDate: '2025-06-11',
        reservationTime: '14:30',
        reservationEndTime: '15:00',
      );

  static OrderDetailModel get sampleCreditCardOrder => _base(
        paymentMethod: '신용카드',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _rxProducts,
        isPrescription: true,
        paymentMethodDetail: '(신한카드 / 1234)',
        odAppNo: '00403582',
        reservationDate: '2025-06-11',
        reservationTime: '14:30',
        reservationEndTime: '15:00',
      );

  static OrderDetailModel get sampleBankTransferOrder => _base(
        paymentMethod: '계좌이체',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _rxProducts,
        isPrescription: true,
        paymentMethodDetail: '(KB국민은행)',
        odBankAccount: 'KB국민은행/12345678901234/20250220180000/보미오라',
        reservationDate: '2025-06-11',
        reservationTime: '14:30',
        reservationEndTime: '15:00',
      );

  /// 비대면 + 추가상품 3개 포함 (결제완료 / 가상계좌)
  static OrderDetailModel get sampleVirtualAccountPaidWithSupplyOrder => _base(
        paymentMethod: '가상계좌',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _rxProductsWithSupply,
        isPrescription: true,
        paymentMethodDetail: '(KEB하나은행)',
        odBankAccount: 'KEB하나은행/13396139137937/20250612235900/보미오라',
        reservationDate: '2025-06-11',
        reservationTime: '14:30',
        reservationEndTime: '15:00',
      );

  /// 비대면 + 추가상품 3개 포함 (결제완료 / 신용카드)
  static OrderDetailModel get sampleCreditCardWithSupplyOrder => _base(
        paymentMethod: '신용카드',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _rxProductsWithSupply,
        isPrescription: true,
        paymentMethodDetail: '(신한카드 / 1234)',
        odAppNo: '00403582',
        reservationDate: '2025-06-11',
        reservationTime: '14:30',
        reservationEndTime: '15:00',
      );

  static OrderDetailModel get sampleGeneralCreditCardOrder => _base(
        paymentMethod: '신용카드',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _generalProducts,
        isPrescription: false,
        paymentMethodDetail: '(현대카드 / 5678)',
        odAppNo: '11223344',
      );

  static OrderDetailModel get sampleGeneralVirtualAccountPendingOrder => _base(
        paymentMethod: '가상계좌',
        displayStatus: '입금대기',
        odStatus: 'pending',
        products: _generalProducts,
        isPrescription: false,
        paymentMethodDetail: '(KEB하나은행)',
        odBankAccount: 'KEB하나은행/13396139137937/20250612235900/(주)세린헬스',
        orderDate: '2025.06.04',
      );

  static OrderDetailModel get sampleGeneralVirtualAccountPaidOrder => _base(
        paymentMethod: '가상계좌',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _generalProducts,
        isPrescription: false,
        paymentMethodDetail: '(KEB하나은행)',
        odBankAccount: 'KEB하나은행/13396139137937/20250612235900/보미오라',
      );

  static OrderDetailModel get sampleGeneralBankTransferOrder => _base(
        paymentMethod: '계좌이체',
        displayStatus: '결제완료',
        odStatus: '입금',
        products: _generalProducts,
        isPrescription: false,
        paymentMethodDetail: '(KB국민은행)',
        odBankAccount: 'KB국민은행/12345678901234/20250220180000/보미오라',
      );

  @Deprecated('Use sampleVirtualAccountPaidOrder')
  static OrderDetailModel get samplePaidOrder => sampleVirtualAccountPaidOrder;

  @Deprecated('Use sampleVirtualAccountPendingOrder')
  static OrderDetailModel get sampleVirtualAccountOrder =>
      sampleVirtualAccountPendingOrder;
}
