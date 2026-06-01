import '../../../../core/constants/app_assets.dart';

/// 환불 계좌 등 은행명 → SVG 아이콘 경로
String? bankIconAssetForName(String bankName) {
  final n = bankName.trim();
  if (n.isEmpty) return null;

  if (n.contains('국민')) return AppAssets.KBIcon;
  if (n.contains('신한은행')) return AppAssets.SHIcon;
  if (n.contains('수협')) return AppAssets.SHIcon;
  if (n.contains('우리')) return AppAssets.WOORIIcon;
  if (n.contains('하나')) return AppAssets.KEBIcon;
  if (n.contains('농협')) return AppAssets.NHIcon;
  if (n.contains('기업')) return AppAssets.IBKIcon;
  if (n.contains('카카오')) return AppAssets.KAKAOIcon;
  if (n.contains('케이뱅크')) return AppAssets.KIcon;
  if (n.contains('토스')) return AppAssets.TOSSIcon;
  // 부산·대구·경남 → DG
  if (n.contains('부산') || n.contains('대구') || n.contains('경남')) {
    return AppAssets.DGIcon;
  }
  // 광주·전북 → JB
  if (n.contains('광주') || n.contains('전북')) {
    return AppAssets.JBIcon;
  }
  if (n.contains('제주')) return AppAssets.JJIcon;
  if (n.contains('우체국')) return AppAssets.POSTIcon;
  if (n.contains('SC제일') || n.contains('제일')) return AppAssets.SCIcon;
  if (n.contains('씨티')) return AppAssets.CITIIcon;

  return null;
}
