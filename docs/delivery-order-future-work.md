# 배송·주문·교환/환불 — 추후 작업 (TODO)

주문/배송·교환/환불·가상계좌 취소 관련 **UI는 일부 구현 완료** 상태입니다.  
아래 항목은 **백엔드 연동·검증·정책 확정** 후 진행할 작업 목록입니다.

---

## 1. 가상계좌 주문 취소 + 환불 계좌

### 구현됨 (프론트)

| 항목 | 경로 |
|------|------|
| 환불 계좌 입력 팝업 | `lib/presentation/user/delivery/widgets/refund_account_popup.dart` |
| 취소 플로우 (확인 → 가상계좌 시 팝업 → API) | `lib/presentation/user/delivery/widgets/order_flow_dialogs.dart` → `runOrderCancelFlow` |
| 환불계좌 조회·저장 API | `lib/data/services/refund_account_service.dart` (`GET/PUT /api/user/refund-account`) |
| 취소 API 본문 (가상계좌 시) | `OrderService.cancelOrder` — `refundBank`, `refundAccount`, `refundHolder` |

### 추후 작업

- [ ] **백엔드** `POST /api/orders/{odId}/cancel` 에서 환불 계좌 필드 수신·검증·주문 취소/환불 처리
- [ ] 가상계좌 **입금 전 / 입금 후** 취소 정책별 분기 (에러 메시지·취소 가능 여부)
- [ ] **계좌이체** 결제 취소 시에도 환불 계좌 팝업이 필요한지 기획 확인 후, 필요 시 `runOrderCancelFlow` 결제수단 조건 확장
- [ ] 취소 실패 시 사용자 메시지(서버 `error` / `message`) 매핑 정리
- [ ] 환불계좌 저장 실패해도 취소는 진행할지, 둘 다 롤백할지 정책 결정

---

## 2. 구매 확정 (수령확인)

### 현상

- `POST /api/orders/{odId}/confirm` 호출 시 **400** 응답 사례 있음 (로그: `구매 확정` 실패)

### 추후 작업

- [ ] 백엔드: 확정 가능 주문 상태·필수 파라미터(`mbId` 등) 확인 및 400 원인 수정
- [ ] 프론트: 실패 시 `SnackBar` 등으로 `message` 노출 (`delivery_service.dart` / 호출 화면)
- [ ] 배송중(`od_status` 등)과 `displayStatus` 불일치 시 확정 버튼 노출 조건 재검토

---

## 3. 교환/환불 신청

### 구현됨 (프론트 UI)

| 화면 | 라우트 | 파일 |
|------|--------|------|
| 비대면(처방) | `/refund` | `refund_apply_prescription_screen.dart` |
| 일반 상품 | `/refund-general` | `refund_apply_general_screen.dart` |
| 공통 상수·사유 | — | `refund_reason_status.dart` |

**처방 전용**

- 교환 탭: 운송장·제품 사진 필수, 「다른 단계로 변경 필요」 시 선택 상품만 별도 카드 + 변경 수량
- 환불 탭: 상세 사유 제목 스타일 분리

**일반**

- 사진 선택(최대 3장), 기본 탭 환불신청

### 추후 작업

- [ ] **교환/환불 신청 API** 설계·연동 (현재 「신청하기」 → 준비 중 `SnackBar`)
- [ ] 요청 본문: `odId`, 탭(교환/환불), 선택 상품·수량, 사유, 상세 사유, 사진(멀티파트)
- [ ] 「다른 단계로 변경 필요」: 변경 수량·상담 연계 백엔드/CS 프로세스
- [ ] 사진: 운송장 1 + 제품 2(처방), 일반 3장 — 용량·포맷 서버 검증
- [ ] 목록/상세 **교환취소·환불취소** 버튼 (`onTap: null`) API·화면 연동

---

## 4. 기타 UI·데이터

- [ ] 주문 목록 `OrderListModel`에 `paymentMethod` 추가 시, 취소 시 상세 조회 1회 생략 가능
- [ ] 교환/환불 가능 주문 상태·기한 정책을 서버 기준으로 버튼 노출 통일
- [ ] `refund_account_screen.dart` 은행 목록과 `RefundBankAccountPopup.bankNames` 중복 — 공통 상수 파일로 통합 검토

---

## 5. 관련 백엔드 API (참고)

| 용도 | 메서드·경로 |
|------|-------------|
| 환불계좌 조회 | `GET /api/user/refund-account?mb_id=` |
| 환불계좌 저장 | `PUT /api/user/refund-account` |
| 주문 취소 | `POST /api/orders/{odId}/cancel` |
| 구매 확정 | `POST /api/orders/{odId}/confirm` |
| 주문 상세 | `GET /api/orders/{odId}` (또는 동일 패턴) |

백엔드 저장소: `bomiora_back` (별도 경로) — 스펙 변경 시 이 문서와 프론트 서비스 레이어를 함께 수정.

---

## 6. 테스트 체크리스트 (연동 후)

- [ ] 가상계좌 주문 → 주문취소 → 환불 계좌 팝업(기등록 계좌 자동 입력) → 확인 → 취소 완료
- [ ] 카드/계좌이체 주문 취소 시 팝업 없이 취소만
- [ ] 처방/일반 각각 교환·환불 신청 E2E
- [ ] 구매 확정 200 및 목록/상세 상태 갱신

---

*마지막 정리: 교환/환불 UI·가상계좌 환불계좌 팝업 프론트 반영 기준.*
