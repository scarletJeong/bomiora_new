import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFaqItem(
          question: '비대면 진료는 어떻게 진행되나요?',
          answer: '''
비대면 진료는 다음과 같이 진행됩니다:

1. 문진표 작성: 건강 상태와 증상을 입력합니다.
2. 의사 상담: 전문의가 문진표를 검토하고 진료합니다.
3. 처방전 발급: 필요한 경우 처방전이 발급됩니다.
4. 약 배송: 처방약이 집으로 배송됩니다.

전체 과정은 보통 1-2일 정도 소요됩니다.
          ''',
        ),
        _buildFaqItem(
          question: '결제 수단은 어떤 것들이 있나요?',
          answer: '''
다음의 결제 수단을 이용하실 수 있습니다:

• 신용카드/체크카드
• 계좌이체
• 무통장입금
• 네이버페이
• 카카오페이
• 토스페이

안전한 PG사를 통해 결제가 진행됩니다.
          ''',
        ),
        _buildFaqItem(
          question: '배송은 얼마나 걸리나요?',
          answer: '''
배송 기간은 다음과 같습니다:

• 일반 상품: 주문 후 2-3일
• 처방약: 처방전 발급 후 2-3일
• 제주/도서산간: 추가 2-3일

영업일 기준이며, 주말/공휴일은 제외됩니다.
          ''',
        ),
        _buildFaqItem(
          question: '반품/교환은 어떻게 하나요?',
          answer: '''
반품/교환 절차:

1. 고객센터 문의 또는 1:1 문의 작성
2. 반품 사유 확인
3. 상품 회수
4. 환불 또는 교환 진행

※ 단순 변심: 상품 수령 후 7일 이내
※ 상품 하자: 수령 후 14일 이내
※ 처방약은 반품/교환이 불가능합니다.
          ''',
        ),
        _buildFaqItem(
          question: '쿠폰은 어떻게 사용하나요?',
          answer: '''
쿠폰 사용 방법:

1. 마이페이지 > 쿠폰함에서 보유 쿠폰 확인
2. 상품 주문 시 쿠폰 선택
3. 할인가격 확인 후 결제

※ 쿠폰은 사용 조건과 유효기간이 있습니다.
※ 일부 쿠폰은 중복 사용이 불가능합니다.
          ''',
        ),
        _buildFaqItem(
          question: '포인트는 어떻게 적립되나요?',
          answer: '''
포인트 적립 방법:

• 회원가입: 1,000P
• 상품 구매: 구매금액의 1-5%
• 리뷰 작성: 500-1,000P
• 이벤트 참여: 이벤트별 상이

적립된 포인트는 1P = 1원으로 사용 가능합니다.
최소 사용 금액은 5,000P부터입니다.
          ''',
        ),
      ],
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3787).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              color: Color(0xFFFF3787),
              size: 20,
            ),
          ),
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              answer.trim(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

