part of 'blood_pressure_list_screen.dart';

class _PressureLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _PressureLegend({required this.color, required this.label});

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

class _GraphSeriesLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _GraphSeriesLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final dot = healthDp(context, 12);
    final gap = healthDp(context, 5);
    final fontSize = healthSp(context, 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
