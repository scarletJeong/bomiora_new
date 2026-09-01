import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 아이디 찾기 결과 — 등록된 이메일(아이디) 선택 리스트
class RegisteredAccountList extends StatelessWidget {
  const RegisteredAccountList({
    super.key,
    required this.accounts,
    required this.selectedIndex,
    required this.onSelect,
    this.sectionTitle,
    this.topSpacing = 10,
  });

  final List<String> accounts;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String? sectionTitle;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topSpacing > 0) SizedBox(height: healthDp(context, topSpacing)),
        if (sectionTitle != null) ...[
          Padding(
            padding: EdgeInsets.only(bottom: healthDp(context, 20)),
            child: Text(
              sectionTitle!,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.black,
                fontSize: healthSp(context, 16),
                height: 1,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        Column(
          children: List.generate(accounts.length, (index) {
            final isSelected = index == selectedIndex;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == accounts.length - 1 ? 0 : healthDp(context, 5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(index),
                  borderRadius: BorderRadius.circular(healthDp(context, 12)),
                  child: _RegisteredAccountTile(
                    email: accounts[index],
                    selected: isSelected,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RegisteredAccountTile extends StatelessWidget {
  const _RegisteredAccountTile({
    required this.email,
    required this.selected,
  });

  final String email;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: ShapeDecoration(
        color: selected ? const Color(0x0CFF5C8F) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: selected
                ? const Color(0xFFFF5C8F)
                : const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              email,
              style: TextStyle(
                color: Colors.black,
                fontSize: healthSp(context, 16),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
              ),
            ),
          ),
          Container(
            width: healthDp(context, 20),
            height: healthDp(context, 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFF5C8F) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                width: healthDp(context, 1),
                color: selected
                    ? const Color(0xFFFF5C8F)
                    : const Color(0xFFD2D2D2),
              ),
            ),
            child: selected
                ? Container(
                    width: healthDp(context, 6.25),
                    height: healthDp(context, 6.25),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
