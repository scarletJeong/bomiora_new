import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../../../data/services/health_sync_service.dart';

class HealthConnectScreen extends StatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  State<HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends State<HealthConnectScreen> {
  static const _kSamsung = '삼성 헬스';
  static const _kApple = '애플 건강 (HealthKit)';
  static const _kGoogle = '구글 핏';

  final Map<String, bool> _connectionState = {
    _kApple: false,
    _kSamsung: false,
    _kGoogle: false,
  };

  String? _selectedServiceName;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool _isSyncing = false;
  int? _syncedSteps;
  int? _syncedHeartRate;

  Future<void> _onConnectBarPressed() async {
    if (_selectedServiceName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연동할 건강 앱을 먼저 선택해주세요.')),
      );
      return;
    }
    await _toggleConnection(_selectedServiceName!);
  }

  Future<void> _toggleConnection(String serviceName) async {
    final isSupported = _isSupportedOnCurrentDevice(serviceName);
    if (!isSupported) {
      final platformName =
          _isIOS ? 'iOS' : _isAndroid ? 'Android' : '현재 플랫폼';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$serviceName 는 $platformName 에서 지원되지 않습니다.')),
      );
      return;
    }

    final isConnected = _connectionState[serviceName] ?? false;
    if (isConnected) {
      setState(() {
        _connectionState[serviceName] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$serviceName 연동 해제')),
      );
      return;
    }

    setState(() => _isSyncing = true);
    final result = await HealthSyncService.connectAndFetchToday();
    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _connectionState[serviceName] = result.success;
      if (result.success) {
        _syncedSteps = result.steps;
        _syncedHeartRate = result.heartRate;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success ? '$serviceName 연동 완료' : result.message),
      ),
    );
  }

  bool _isSupportedOnCurrentDevice(String serviceName) {
    if (serviceName.contains('애플')) return _isIOS;
    if (serviceName.contains('삼성') || serviceName.contains('구글')) {
      return _isAndroid;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(title: '연동하기'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(27, 20, 27, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 5),
                              child: Text(
                                '연동하기',
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 16,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16, height: 16),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '사용 중인 건강 어플을 선택 후 연동해주세요.',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildProviderBlock(
                          serviceName: _kSamsung,
                          label: '삼성 헬스',
                          child: _SamsungHealthMark(),
                        ),
                        const SizedBox(height: 24),
                        _buildProviderBlock(
                          serviceName: _kApple,
                          label: '애플 건강',
                          child: _AppleHealthMark(),
                        ),
                        const SizedBox(height: 24),
                        _buildProviderBlock(
                          serviceName: _kGoogle,
                          label: 'Google Fit',
                          child: _GoogleFitMark(),
                        ),
                      ],
                    ),
                  ),
                  if (_syncedSteps != null || _syncedHeartRate != null) ...[
                    const SizedBox(height: 32),
                    _buildSyncedSummary(),
                  ],
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(27, 0, 27, 20),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSyncing ? null : _onConnectBarPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A8D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFFF5A8D)
                        .withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isSyncing ? '연동 중…' : '연동하기',
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderBlock({
    required String serviceName,
    required String label,
    required Widget child,
  }) {
    final selected = _selectedServiceName == serviceName;
    final connected = _connectionState[serviceName] ?? false;
    final supported = _isSupportedOnCurrentDevice(serviceName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedServiceName = serviceName),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFF5A8D)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Opacity(
                  opacity: supported ? 1 : 0.45,
                  child: child,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                connected ? '$label · 연동됨' : label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: supported
                      ? const Color(0xFF898383)
                      : const Color(0xFFB3B3B3),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncedSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '동기화 미리보기',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '걸음수: ${_syncedSteps?.toString() ?? '-'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
          Text(
            '심박수: ${_syncedHeartRate != null ? '$_syncedHeartRate bpm' : '-'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}

/// 삼성 헬스 톤 그라데이션 마크 (100×100)
class _SamsungHealthMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8C9EFF),
            Color(0xFF1DE9B6),
            Color(0xFF29B6F6),
          ],
        ),
      ),
    );
  }
}

class _AppleHealthMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1.55,
              ),
            ),
          ),
          Container(
            width: 47,
            height: 41,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF5DA3),
                  Color(0xFFFF435F),
                  Color(0xFFFF291D),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFF5DA3),
                width: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleFitMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1.55,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 14,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBC05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF34A853),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
