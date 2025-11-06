import 'package:flutter/material.dart';
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
      child: TabBarView(
        controller: _tabController,
        children: [
          const FaqScreen(),
          ContactListScreen(key: _contactListKey),
          ContactFormScreen(onSuccess: _onContactSubmitSuccess),
        ],
      ),
    );
  }
}

