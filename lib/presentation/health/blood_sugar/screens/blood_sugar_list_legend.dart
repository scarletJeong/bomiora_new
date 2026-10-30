part of 'blood_sugar_list_screen.dart';

class _SugarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _SugarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: healthDp(context, 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: healthDp(context, 10),
            height: healthDp(context, 10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: healthDp(context, 3)),
          Text(
            label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
