import 'package:flutter/material.dart';
import 'webview_screen.dart';
import '../widgets/mobile_layout_wrapper.dart';

class HybridShoppingScreen extends StatelessWidget {
  const HybridShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text('보미오라 쇼핑몰'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      child: ListView(
        children: [
          // Flutter로 만든 메인 화면
          Container(
            height: 200,
            color: Colors.blue[50],
            child: const Center(
              child: Text(
                'Flutter로 만든 메인 화면',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          // 기존 PHP 쇼핑몰 페이지들
          _buildMenuTile(
            context,
            '상품 목록',
            'https://bomiora0.mycafe24.com/shop/list.php?mobile_app=1&hide_header=1&hide_footer=1',
            Icons.shopping_bag,
          ),
          _buildMenuTile(
            context,
            '장바구니',
            'https://bomiora0.mycafe24.com/shop/cart.php?mobile_app=1&hide_header=1&hide_footer=1',
            Icons.shopping_cart,
          ),
          _buildMenuTile(
            context,
            '주문 내역',
            'https://bomiora0.mycafe24.com/shop/orderlist.php?mobile_app=1&hide_header=1&hide_footer=1',
            Icons.receipt,
          ),
          _buildMenuTile(
            context,
            '회원 정보',
            'https://bomiora0.mycafe24.com/bbs/member_confirm.php?mobile_app=1&hide_header=1&hide_footer=1',
            Icons.person,
          ),
          _buildMenuTile(
            context,
            '결제 페이지',
            'https://bomiora0.mycafe24.com/shop/orderform.php?mobile_app=1&hide_header=1&hide_footer=1',
            Icons.payment,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    String title,
    String url,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: url,
              title: title,
            ),
          ),
        );
      },
    );
  }
}
