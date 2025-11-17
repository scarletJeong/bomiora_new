import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faq_screen.dart';
import 'contact_list_screen.dart';
import 'contact_form_screen.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class CustomerServiceScreen extends StatefulWidget {
  final int initialTabIndex;

  const CustomerServiceScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ContactListScreenState> _contactListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // 탭 변경 시 내 문의내역 새로고침
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        // "내 문의내역" 탭으로 이동했을 때
        _contactListKey.currentState?.refresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onContactSubmitSuccess() {
    // 문의 등록 성공 시 "내 문의내역" 탭으로 이동
    _tabController.animateTo(1);
  }

  /// 카카오톡 상담 열기
  Future<void> _openKakaoChannel() async {
    try {
      final url = Uri.parse('http://pf.kakao.com/_NdxgAG');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오톡을 열 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      print('❌ 카카오톡 상담 열기 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오톡 상담 연결에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '고객센터',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF3787),
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: const Color(0xFFFF3787),
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: '내 문의내역'),
            Tab(text: '문의하기'),
          ],
        ),
      ),
      child: Column(
        children: [
          // 카카오톡 상담 배너
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEE500), Color(0xFFFFD700)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openKakaoChannel,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 카카오톡 아이콘
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.brown[800],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 텍스트
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💬 카카오톡으로 상담하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '빠른 답변을 받아보세요',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.brown[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 화살표 아이콘
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.brown[800],
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 탭 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const FaqScreen(),
                ContactListScreen(key: _contactListKey),
                ContactFormScreen(onSuccess: _onContactSubmitSuccess),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

