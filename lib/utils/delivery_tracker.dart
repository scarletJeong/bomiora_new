import 'package:url_launcher/url_launcher.dart';

/// 택배사별 배송 조회 URL 매핑
class DeliveryTracker {
  
  /// 택배사별 조회 URL 맵
  static final Map<String, DeliveryCompanyInfo> _companyMap = {
    'CJ대한통운': DeliveryCompanyInfo(
      name: 'CJ대한통운',
      url: 'https://trace.cjlogistics.com/next/tracking.html?wblNo=',
      needsHyphenRemoval: true, // 하이픈 제거 필요
    ),
    '한진택배': DeliveryCompanyInfo(
      name: '한진택배',
      url: 'https://www.hanjin.com/kor/CMS/DeliveryMgr/WaybillResult.do?mCode=MN038&schLang=KR&wblnumText2=',
      needsHyphenRemoval: false,
    ),
    '우체국택배': DeliveryCompanyInfo(
      name: '우체국택배',
      url: 'https://service.epost.go.kr/trace.RetrieveDomRigiTraceList.comm?sid1=',
      needsHyphenRemoval: false,
    ),
    '로젠택배': DeliveryCompanyInfo(
      name: '로젠택배',
      url: 'https://www.ilogen.com/web/personal/trace/',
      needsHyphenRemoval: false,
    ),
    'GTX로지스': DeliveryCompanyInfo(
      name: 'GTX로지스',
      url: 'https://www.gtxlogis.co.kr/tracking?invoice_no=',
      needsHyphenRemoval: false,
    ),
    '롯데택배': DeliveryCompanyInfo(
      name: '롯데택배',
      url: 'https://www.lotteglogis.com/home/reservation/tracking/index?InvNo=',
      needsHyphenRemoval: false,
    ),
    '대한통운': DeliveryCompanyInfo(
      name: '대한통운',
      url: 'https://www.doortodoor.co.kr/parcel/doortodoor.do?fsp_action=PARC_ACT_002&fsp_cmd=retrieveInvNoACT&invc_no=',
      needsHyphenRemoval: false,
    ),
    '경동택배': DeliveryCompanyInfo(
      name: '경동택배',
      url: 'https://kdexp.com/basicNewDelivery.kd?barcode=',
      needsHyphenRemoval: false,
    ),
  };
  
  /// 배송 조회 URL 생성
  /// 
  /// [companyName] 택배사명
  /// [trackingNumber] 운송장번호
  /// 
  /// 반환: 조회 URL (없으면 null)
  static String? getTrackingUrl(String? companyName, String? trackingNumber) {
    if (companyName == null || companyName.isEmpty) return null;
    if (trackingNumber == null || trackingNumber.isEmpty) return null;
    
    // 택배사 정보 찾기
    DeliveryCompanyInfo? companyInfo;
    
    // 정확히 일치하는 택배사명 찾기
    if (_companyMap.containsKey(companyName)) {
      companyInfo = _companyMap[companyName];
    } else {
      // 부분 일치 검색 (예: "CJ대한통운(주)" → "CJ대한통운")
      for (var entry in _companyMap.entries) {
        if (companyName.contains(entry.key)) {
          companyInfo = entry.value;
          break;
        }
      }
    }
    
    if (companyInfo == null) {
      return null;
    }
    
    // 운송장번호 처리
    String processedTracking = trackingNumber;
    
    // CJ대한통운인 경우 하이픈 제거
    if (companyInfo.needsHyphenRemoval) {
      processedTracking = trackingNumber.replaceAll('-', '');
    }
    
    // URL 생성
    final url = companyInfo.url + processedTracking;
    
    return url;
  }
  
  /// 배송 조회 링크 열기
  /// 
  /// [companyName] 택배사명
  /// [trackingNumber] 운송장번호
  /// 
  /// 반환: 성공 여부
  static Future<bool> openTrackingPage(String? companyName, String? trackingNumber) async {
    final url = getTrackingUrl(companyName, trackingNumber);
    
    if (url == null) {
      return false;
    }
    
    try {
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 외부 브라우저에서 열기
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  /// 지원하는 택배사 목록
  static List<String> getSupportedCompanies() {
    return _companyMap.keys.toList();
  }
  
  /// 택배사가 지원되는지 확인
  static bool isSupported(String? companyName) {
    if (companyName == null || companyName.isEmpty) return false;
    
    // 정확히 일치하는지 확인
    if (_companyMap.containsKey(companyName)) return true;
    
    // 부분 일치 확인
    for (var key in _companyMap.keys) {
      if (companyName.contains(key)) return true;
    }
    
    return false;
  }
}

/// 택배사 정보
class DeliveryCompanyInfo {
  final String name;
  final String url;
  final bool needsHyphenRemoval;
  
  DeliveryCompanyInfo({
    required this.name,
    required this.url,
    this.needsHyphenRemoval = false,
  });
}

