# Step 2 — 출시 후 (다음 단계)

**1차 출시 범위에서 제외.** 지금은 개발하지 않고, 출시 이후에 진행합니다.

교환·환불 관련 UI 골격만 있고, **주문 화면 진입·신청 API·사진 업로드·submit**이 미완입니다.  
상세 스펙·테스트 체크리스트는 [`docs/delivery-order-future-work.md`](docs/delivery-order-future-work.md)도 함께 참고하세요.

출시 전 작업 목록은 [`개발해야할것.md`](개발해야할것.md)를 보세요.

---

## 할 일 목록

| # | 항목 | 설명 | 관련 파일 |
|---|------|------|-----------|
| 2-1 | **주문 목록/상세 → 교환·환불 진입** | `/refund`, `/refund-general` 라우트만 있고 주문 화면에 **버튼·네비게이션 없음.** | `delivery_list_screen.dart`, `delivery_detail_screen.dart`, `main.dart` |
| 2-2 | **일반 교환/환불 신청 제출** | UI·유효성 검사만 있고 `_submit()`이 API 호출·완료 화면 없음. | `refund_apply_general_screen.dart` |
| 2-3 | **처방 교환/환불 신청** | 사진·사유 입력 후 상담 예약 팝업까지만 동작. **신청 API·사진 업로드 없음.** | `refund_apply_prescription_screen.dart` |
| 2-4 | **교환/환불 사진 업로드** | 로컬 선택·표시만. 서버 멀티파트 업로드 미연동. | `refund_apply_photo_utils.dart` |
| 2-5 | **교환/환불 신청 API 설계·연동** | `odId`, 교환/환불 탭, 선택 상품·수량, 사유, 상세 사유, 사진 등 스펙·엔드포인트 필요. | `refund_apply_*_screen.dart`, `api_endpoints.dart` |
| 2-6 | **교환/환불 버튼 노출 정책** | 주문 상태·기한에 따른 버튼 표시를 서버 기준으로 통일. | `delivery_list_screen.dart`, `delivery_detail_screen.dart` |
| 2-7 | **처방 「다른 단계로 변경」** | 변경 수량·상담 연계 CS/백엔드 프로세스 확정 필요. | `refund_apply_prescription_screen.dart` |
| 2-8 | **교환/환불 취소** | 신청 후 교환취소·환불취소 버튼·API (UI에 `onTap: null` 등 미연동 상태). | `delivery-order-future-work.md` 참고 |
| 2-9 | **체험단(모집·신청)** | PHP `shop/tester.php`, `tester_item.php`, `tester_apply.php` 대응. API 경로만 있고 화면 없음. | `api_endpoints.dart` (`/api/tester/items`, `/api/tester/apply`), 신규 화면 |

---

## 처방 vs 일반

| | 처방 (`/refund`) | 일반 (`/refund-general`) |
|--|------------------|--------------------------|
| 화면 | `refund_apply_prescription_screen.dart` | `refund_apply_general_screen.dart` |
| UI | 운송장·제품 사진 필수, 상담 예약 팝업 | 사진 최대 3장, 단순 폼 |
| 교환 탭 | 단계 변경(상담 연계), 변경 수량 UI | 교환/환불 공통 사유 |
| 현재 상태 | UI만, API 없음 | UI만, submit 없음 |

---

## 이미 있는 것 (출시 후에 이어서 연동)

- 교환/환불 신청 화면 UI (처방·일반 각 1종)
- 라우트 등록 (`main.dart` — `/refund`, `/refund-general`)
- 사유·탭 공통 상수 (`refund_reason_status.dart`)
- 상담 예약 확인 팝업 (`consult_confirm_popup.dart`)
- 환불계좌 등록/조회 (`refund_account_service.dart`, 마이페이지) — **주문 취소**용, 교환/환불 신청과는 별도

---

## 권장 진행 순서 (출시 후)

1. 백엔드 교환/환불 신청 API 스펙 확정
2. 주문 목록/상세에 진입 버튼 추가 (상태·기한 조건)
3. 사진 업로드 연동
4. 일반 `submit` → 처방 `submit` (상담 예약 + API)
5. 신청 취소·진행 상태 조회 (필요 시)

---

## 테스트 체크리스트 (연동 후)

- [ ] 처방 주문 — 교환 신청 E2E (사진, 상담 예약, API)
- [ ] 처방 주문 — 환불 신청 E2E
- [ ] 일반 주문 — 교환·환불 신청 E2E
- [ ] 신청 불가 주문(기한·상태)에서 버튼 미노출
- [ ] 사진 용량·포맷 서버 검증

---

*1차 출시 후 교환/환불 단계 작업 목록.*
