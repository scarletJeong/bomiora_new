import 'package:flutter/material.dart';

import 'agreement_popup_dialog.dart';

class LocationServicePopup extends StatelessWidget {
  const LocationServicePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgreementPopupDialog(
      title: '위치기반서비스 이용약관',
      subtitle: '위치기반서비스 이용약관',
      body: '위치기반서비스 이용약관 내용은 추후 제공 예정입니다.',
    );
  }
}
