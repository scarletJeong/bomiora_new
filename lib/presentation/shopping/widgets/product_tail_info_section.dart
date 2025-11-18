import 'package:flutter/material.dart';

/// 제품 상세페이지 공통 정보 섹션 (배송, 처방 프로세스, 교환/환불)
class ProductTailInfoSection extends StatelessWidget {
  const ProductTailInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // 배송 정보
          _buildDeliverySection(),
          const SizedBox(height: 12),
          
          // 처방 프로세스
          _buildPrescriptionProcessSection(),
          const SizedBox(height: 12),
          
          // 교환/환불
          _buildExchangeRefundSection(),
        ],
      ),
    );
  }

  /// 배송 정보 섹션
  Widget _buildDeliverySection() {
    return ExpansionTile(
      title: const Text(
        '배송',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                '배송비',
                '30,000원 미만 주문시 3,000원, 30,000원 이상 무료배송',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                '배송 안내',
                '평일 오후 2시 이전 처방 완료 시 당일 발송 또는 익일 배송 가능',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 처방 프로세스 섹션
  Widget _buildPrescriptionProcessSection() {
    return ExpansionTile(
      title: const Text(
        '처방 프로세스',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProcessStep(
                '01',
                '건강프로필 작성',
                '원하는 제품을 선택하고 "처방 예약하기" 버튼을 클릭하여 건강프로필를 작성하세요.\n건강프로필 정보는 담당 의사에게만 제공되며, 개인정보 노출 위험은 없습니다.',
              ),
              const SizedBox(height: 16),
              _buildProcessStep(
                '02',
                '결제',
                '결제 후 진료 예약이 등록되며, 담당 의사 안내는 문자 또는 카카오톡으로 받으실 수 있습니다.',
              ),
              const SizedBox(height: 16),
              _buildProcessStep(
                '03',
                '상담 및 진료',
                '예약된 시간에 담당 의사가 전화를 드리며, 상담 및 진료가 진행됩니다.\n비대면 상담, 재진, 초진 모두 가능합니다.',
              ),
              const SizedBox(height: 16),
              _buildProcessStep(
                '04',
                '처방 및 배송',
                '오후 2시 이전 처방 완료 시 당일 발송 또는 익일 배송이 가능합니다.',
              ),
              const SizedBox(height: 16),
              _buildProcessStep(
                '05',
                '복용 후 리뷰',
                '제품 복용 후 리뷰를 작성하시면 최대 2,000 포인트를 적립 받으실 수 있습니다.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 교환/환불 섹션
  Widget _buildExchangeRefundSection() {
    return ExpansionTile(
      title: const Text(
        '교환/환불',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 반품/교환 사유에 따른 요청 가능 기간
              const Text(
                '반품/교환 사유에 따른 요청 가능 기간',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '처방 의약품의 경우 개인별 증상/효과의 차이가 있을 수 있어, 담당 한의사와 충분한 상담 후 환불 처리됩니다. 고객님께서는 먼저 담당 의사와 연락하여 반품 사유, 택배, 배송비, 반품 주소를 상담한 후 제품을 발송해주세요. 처방 의원의 정책에 따라 환불 절차가 달라질 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              
              // 1. 처방완료 후, 환자 단순 변심은 10일 이내
              _buildRefundItem(
                '1. 처방완료 후, 환자 단순 변심은 10일 이내',
                '반품/교환 배송비 6,000원 구매자 부담',
                '반품 주소: 서울 강남구 봉은사로 109, 6층(논현동)',
              ),
              const SizedBox(height: 16),
              
              // 2. 표시와 상이, 의약품 문제의 경우
              _buildRefundItem(
                '2. 표시와 상이, 의약품 문제의 경우, 담당 한의사와 상담 후 반품 방법을 안내 받아 환불 진행',
                '반품 배송비 무료 (한의원 부담)',
                '반품 주소: 서울 강남구 봉은사로 109, 6층(논현동)',
              ),
              const SizedBox(height: 20),
              
              // 환불/교환 불가능 사유
              const Text(
                '환불/교환 불가능 사유',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildBulletPoint('반품 요청기간이 지난 경우'),
              _buildBulletPoint('환자의 책임 있는 사유로 의약품 등이 멸실 또는 훼손된 경우'),
            ],
          ),
        ),
      ],
    );
  }

  /// 프로세스 단계 위젯
  Widget _buildProcessStep(String step, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4081),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 환불 항목 위젯
  Widget _buildRefundItem(String title, String cost, String address) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('배송비', cost),
          const SizedBox(height: 4),
          _buildInfoRow('반품 주소', address),
        ],
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 불릿 포인트 위젯
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
