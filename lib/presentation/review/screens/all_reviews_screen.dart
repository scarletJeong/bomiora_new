import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import 'review_detail_screen.dart';

/// 전체 리뷰 목록 화면
class AllReviewsScreen extends StatefulWidget {
  const AllReviewsScreen({super.key});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  
  List<ReviewModel> _generalReviews = [];
  List<ReviewModel> _supporterReviews = [];
  
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasMore = true;
  
  // 리뷰 통계
  int _generalCount = 0;
  int _supporterCount = 0;
  Map<String, double> _averageScores = {
    'score1': 0.0, // 효과
    'score2': 0.0, // 가성비
    'score3': 0.0, // 맛/향
    'score4': 0.0, // 편리함
    'total': 0.0,  // 전체 평균
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 전체 탭 제거
    _tabController.addListener(_onTabChanged);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentPage = 0;
        _hasMore = true;
      });
      _loadReviews(refresh: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadReviews();
      }
    }
  }

  /// 리뷰 목록 로드
  Future<void> _loadReviews({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 0;
        if (_tabController.index == 0) {
          _supporterReviews.clear();
        } else {
          _generalReviews.clear();
        }
        _hasMore = true;
      }
    });

    try {
      // 탭에 따라 리뷰 종류 결정
      String rvkind = _tabController.index == 0 ? 'supporter' : 'general';

      // 전체 리뷰 조회 (모든 상품의 리뷰)
      final result = await ReviewService.getAllReviews(
        rvkind: rvkind,
        page: _currentPage,
        size: 20,
      );

      if (result['success'] == true) {
        final newReviews = result['reviews'] as List<ReviewModel>;
        final totalElements = result['totalElements'] ?? 0;
        
        setState(() {
          if (_tabController.index == 0) {
            if (refresh) {
              _supporterReviews = newReviews;
              _supporterCount = totalElements;
              // 서포터 리뷰 평균 계산
              _calculateAverageScores(newReviews);
            } else {
              _supporterReviews.addAll(newReviews);
            }
          } else {
            if (refresh) {
              _generalReviews = newReviews;
              _generalCount = totalElements;
              // 일반 리뷰 평균 계산
              _calculateAverageScores(newReviews);
            } else {
              _generalReviews.addAll(newReviews);
            }
          }
          _currentPage++;
          _hasMore = result['hasNext'] ?? false;
        });
      }
    } catch (e) {
      print('리뷰 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰를 불러오는데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 평균 평점 계산
  void _calculateAverageScores(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      _averageScores = {
        'score1': 0.0,
        'score2': 0.0,
        'score3': 0.0,
        'score4': 0.0,
        'total': 0.0,
      };
      return;
    }

    double score1Sum = 0, score2Sum = 0, score3Sum = 0, score4Sum = 0;
    
    for (var review in reviews) {
      score1Sum += review.isScore1;
      score2Sum += review.isScore2;
      score3Sum += review.isScore3;
      score4Sum += review.isScore4;
    }

    final count = reviews.length;
    _averageScores = {
      'score1': score1Sum / count,
      'score2': score2Sum / count,
      'score3': score3Sum / count,
      'score4': score4Sum / count,
      'total': (score1Sum + score2Sum + score3Sum + score4Sum) / (count * 4),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MobileLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            '보미오라 리뷰',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF4081),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFFF4081),
            tabs: [
              Tab(text: '서포터 리뷰 ($_supporterCount)'),
              Tab(text: '일반 리뷰 ($_generalCount)'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildReviewList(_supporterReviews, isGrid: true), // 서포터 리뷰는 그리드
            _buildReviewList(_generalReviews, isGrid: false),  // 일반 리뷰는 리스트
          ],
        ),
      ),
    );
  }

  Widget _buildReviewList(List<ReviewModel> reviews, {required bool isGrid}) {
    if (_isLoading && reviews.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF4081),
        ),
      );
    }

    if (reviews.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadReviews(refresh: true),
      color: const Color(0xFFFF4081),
      child: isGrid
          ? _buildGridView(reviews)
          : _buildListView(reviews),
    );
  }

  /// 그리드 뷰 (서포터 리뷰용)
  Widget _buildGridView(List<ReviewModel> reviews) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 평균 평점 섹션
        SliverToBoxAdapter(
          child: _buildAverageScoresSection(),
        ),
        
        // 그리드 리뷰 목록
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65, // 카드 크기 키움 (이미지 더 크게)
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= reviews.length) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF4081),
                    ),
                  );
                }
                return _buildGridReviewCard(reviews[index]);
              },
              childCount: reviews.length + (_isLoading ? 2 : 0),
            ),
          ),
        ),
      ],
    );
  }

  /// 리스트 뷰 (일반 리뷰용)
  Widget _buildListView(List<ReviewModel> reviews) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: reviews.length + 1 + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // 첫 번째 아이템은 평균 평점 섹션
        if (index == 0) {
          return _buildAverageScoresSection();
        }
        
        final reviewIndex = index - 1;
        
        if (reviewIndex >= reviews.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Color(0xFFFF4081),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildListReviewCard(reviews[reviewIndex]),
        );
      },
    );
  }

  /// 평균 평점 섹션
  Widget _buildAverageScoresSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 전체 평균
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '평균 평점',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              ...List.generate(5, (index) {
                final rating = _averageScores['total'] ?? 0;
                return Icon(
                  index < rating.round() ? Icons.star : Icons.star_border,
                  size: 24,
                  color: const Color(0xFFFF4081),
                );
              }),
              const SizedBox(width: 8),
              Text(
                _averageScores['total']?.toStringAsFixed(1) ?? '0.0',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF4081),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 세부 평점
          _buildScoreBar('효과', _averageScores['score1'] ?? 0),
          const SizedBox(height: 10),
          _buildScoreBar('가성비', _averageScores['score2'] ?? 0),
          const SizedBox(height: 10),
          _buildScoreBar('맛/향', _averageScores['score3'] ?? 0),
          const SizedBox(height: 10),
          _buildScoreBar('편리함', _averageScores['score4'] ?? 0),
        ],
      ),
    );
  }

  /// 평점 바
  Widget _buildScoreBar(String label, double score) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: score / 5,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '리뷰가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 그리드 리뷰 카드 (서포터 리뷰용 - 2열)
  Widget _buildGridReviewCard(ReviewModel review) {
    return GestureDetector(
      onTap: () {
        // 리뷰 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(
              review: review,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: review.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.network(
                          review.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.rate_review,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.rate_review,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),
            
            // 내용
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성자
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.isName ?? '익명',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (review.isSupporterReview)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '서포터',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // 별점
                  Row(
                    children: List.generate(5, (index) {
                      final rating = review.averageScore ?? 0;
                      return Icon(
                        index < rating.round() ? Icons.star : Icons.star_border,
                        size: 14,
                        color: const Color(0xFFFF4081),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  
                  // 리뷰 내용
                  Text(
                    review.isPositiveReviewText ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // 도움이 돼요
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${review.isGood ?? 0}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 리스트 리뷰 카드 (일반 리뷰용)
  Widget _buildListReviewCard(ReviewModel review) {
    return GestureDetector(
      onTap: () {
        // 리뷰 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(
              review: review,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 정보
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFF4081).withOpacity(0.1),
                    child: Text(
                      review.isName?.substring(0, 1) ?? '?',
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.isName ?? '익명',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (review.isTime != null)
                          Text(
                            '${review.isTime!.year}.${review.isTime!.month.toString().padLeft(2, '0')}.${review.isTime!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 평점
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final rating = review.averageScore ?? 0;
                    return Icon(
                      index < rating.round() ? Icons.star : Icons.star_border,
                      size: 18,
                      color: const Color(0xFFFF4081),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    '${review.averageScore?.toStringAsFixed(1) ?? '0.0'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4081),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 리뷰 내용
              if (review.isPositiveReviewText != null &&
                  review.isPositiveReviewText!.isNotEmpty)
                Text(
                  review.isPositiveReviewText!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              // 도움이 돼요
              Row(
                children: [
                  Icon(
                    Icons.thumb_up,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${review.isGood ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

