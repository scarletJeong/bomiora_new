import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '개인정보 처리방침',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '개인정보취급방침',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '(주)보미오라는 고객님의 개인 민감정보 보호를 중요시하며, "개인 민감정보 보호법"과 "정보통신망 이용촉진 및 정보보호"에 관한 법률을 준수하고 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '(주)보미오라는 개인정보취급방침을 통하여 고객님께서 제공하시는 개인정보가 어떠한 용도와 방식으로 이용되고 있으며, 개인정보보호를 위해 어떠한 조치가 취해지고 있는지 알려드립니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '(주)보미오라는 개인정보취급방침을 개정하는 경우 웹사이트 공지사항(또는 개별공지)을 통하여 공지할 것입니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '개인정보관리책임자',
              '성명 : 정대진\n연락처 : 02-546-1031',
            ),
            
            _buildSection(
              '개인정보 제공',
              '회사는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다. 다만, 아래의 경우에는 예외로 합니다.\nο 이용자들이 사전에 동의한 경우\nο 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우',
            ),
            
            _buildSection(
              '수집한 개인정보의 위탁',
              '회사는 고객서비스 관리 및 민원사항에 대한 등 원활한 업무 수행을 위하여 아래와 같이 개인정보 취급 업무를 위탁하여 운영하고 있습니다.\n또한 위탁계약 시 개인정보보호의 안전을 기하기 위하여 개인정보보호 관련 법규의 준수, 개인정보에 관한 제3자 공급 금지, 사고시의 책임부담 등을 명확히 규정하고 있습니다. 동 업체가 변경될 경우, 변경된 업체 명을 공지사항 내지 개인정보 취급방침 화면을 통해 고지하겠습니다.',
            ),
            
            _buildSection(
              '이용자 및 법정대리인의 권리와 그 행사방법',
              'ο 이용자는 언제든지 등록되어 있는 자신의 개인정보를 조회하거나 수정할 수 있으며 가입해지를 요청할 수도 있습니다.\nο 이용자의 개인정보 조회,수정을 위해서는 "개인정보변경"(또는 "회원정보수정" 등)을, 가입해지(동의철회)를 위해서는 "회원탈퇴"를 클릭 하여 본인 확인 절차를 거치신 후 직접 열람, 정정 또는 탈퇴가 가능합니다. 혹은 개인정보관리책임자에게 서면, 전화 또는 이메일로 연락하시면 지체없이 조치하겠습니다.\nο 귀하가 개인정보의 오류에 대한 정정을 요청하신 경우에는 정정을 완료하기 전까 지 당해 개인정보를 이용 또는 제공하지 않습니다. 또한 잘못된 개인정보를 제3자 에게 이미 제공한 경우에는 정정 처리결과를 제3자에게 지체없이 통지하여 정정이 이루어지도록 하겠습니다.\nο 회사는 이용자 혹은 법정 대리인의 요청에 의해 해지 또는 삭제된 개인정보는 회사가 수집하는 "개인정보의 보유 및 이용기간"에 명시된 바에 따라 처리하고 그 외의 용도로 열람 또는 이용할 수 없도록 처리하고 있습니다.',
            ),
            
            _buildSection(
              '개인정보 자동수집 장치의 설치, 운영 및 그 거부에 관한 사항',
              '회사는 귀하의 정보를 수시로 저장하고 찾아내는 \'쿠키(cookie)\' 등을 운용합니다.\n쿠키란 메디랩스의 웹사이트를 운영하는데 이용되는 서버가 귀하의 브라우저에 보내는 아주 작은 텍스트 파일로서 귀하의 컴퓨터 하드디스크에 저장됩니다.\n회사는 다음과 같은 목적을 위해 쿠키를 사용합니다.\nο 쿠키 등 사용 목적\n- 회원과 비회원의 접속 빈도나 방문 시간 등을 분석, 이용자의 취향과 관심분야를 파악 및 자취 추적, 각종 이벤트 참여 정도 및 방문 회수 파악 등을 통한 타겟 마케팅 및 개인 맞춤 서비스 제공 - 귀하는 쿠키 설치에 대한 선택권을 가지고 있습니다. 따라서, 귀하는 웹브라우저에서 옵션을 설정함으로써 모든 쿠키를 허용하거나, 쿠키가 저장될 때마다 확인을 거치거나, 아니면 모든 쿠키의 저장을 거부할 수도 있습니다.\nο 쿠키 설정 거부 방법\n- 쿠키 설정을 거부하는 방법으로는 회원님이 사용하시는 웹 브라우저의 옵션을 선택함으로써 모든 쿠키를 허용하거나 쿠키를 저장할 때마다 확인을 거치거나, 모든 쿠키의 저장을 거부할 수 있습니다.\n- 설정방법 예 인터넷 익스플로어 : 웹 브라우저 상단의 도구 > 인터넷 옵션 > 개인정보 > 고급 Chrome : 웹 브라우저 상단의 도구 > 설정 > 고급 > 개인정보 및 보안 > 콘텐츠 설정 > 쿠키 - 단, 귀하께서 쿠키 설치를 거부하였을 경우 서비스 제공에 어려움이 있을 수 있습니다.',
            ),
            
            _buildSection(
              '14세 미만 아동의 가입제한',
              '회사는 법적대리인의 동의가 필요한 만14세 미만 아동의 회원가입은 받고 있지 않습니다.',
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

