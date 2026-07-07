/// `bm_banner` 행 (메인·상품목록 공통)
class BannerModel {
  final int id;
  final String title;
  final String linkUrl;
  final String imageUrl;
  final String placement;
  final String targetKind;

  const BannerModel({
    required this.id,
    required this.title,
    required this.linkUrl,
    required this.imageUrl,
    this.placement = 'main',
    this.targetKind = 'all',
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      linkUrl: json['linkUrl']?.toString() ?? json['link_url']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['mo_image']?.toString() ?? '',
      placement: json['placement']?.toString() ?? 'main',
      targetKind:
          json['targetKind']?.toString() ?? json['target_kind']?.toString() ?? 'all',
    );
  }
}
