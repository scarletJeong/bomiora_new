import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/health_sync_service.dart';

class HealthConnectScreen extends StatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  State<HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends State<HealthConnectScreen> {
  final Map<String, bool> _connectionState = {
    '애플 건강 (HealthKit)': false,
    '삼성 헬스': false,
    '구글 핏': false,
  };

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool _isSyncing = false;
  int? _syncedSteps;
  int? _syncedHeartRate;

  Future<void> _toggleConnection(String serviceName) async {
    final isSupported = _isSupportedOnCurrentDevice(serviceName);
    if (!isSupported) {
      final platformName = _isIOS ? 'iOS' : _isAndroid ? 'Android' : '현재 플랫폼';
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
      SnackBar(content: Text(result.success ? '$serviceName 연동 완료' : result.message)),
    );
  }

  bool _isSupportedOnCurrentDevice(String serviceName) {
    if (serviceName.contains('애플')) return _isIOS;
    if (serviceName.contains('삼성') || serviceName.contains('구글')) return _isAndroid;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          '건강 데이터 연동',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '건강앱 연동',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '휴대폰에 설치된 건강 앱과 연동하면 걸음수, 심박수 등의 데이터를 자동으로 가져올 수 있어요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          ..._connectionState.keys.map(_buildServiceCard),
          const SizedBox(height: 24),
          _buildSyncedDataCard(),
          const SizedBox(height: 12),
          _buildAppleHealthGuideCard(),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String serviceName) {
    final connected = _connectionState[serviceName] ?? false;
    final supported = _isSupportedOnCurrentDevice(serviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: connected ? const Color(0xFFFF3787) : const Color(0xFF9EA8B6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  supported
                      ? (connected ? '연동되어 있습니다.' : '연동 대기 중')
                      : '현재 기기에서 지원되지 않음',
                  style: TextStyle(
                    fontSize: 12,
                    color: supported
                        ? (connected ? const Color(0xFF3E8E49) : Colors.grey[600])
                        : const Color(0xFFD64545),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isSyncing ? null : () => _toggleConnection(serviceName),
            child: Text(_isSyncing ? '동기화중' : (connected ? '해제' : '연동')),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedDataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '동기화 데이터 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text('걸음수: ${_syncedSteps?.toString() ?? '-'}'),
          const SizedBox(height: 4),
          Text('최근 심박수: ${_syncedHeartRate != null ? '$_syncedHeartRate bpm' : '-'}'),
        ],
      ),
    );
  }

  Widget _buildAppleHealthGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '애플 건강(HealthKit) 연동 방법',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text('1) iPhone에서 건강 앱(Health)을 열고 데이터 접근을 허용합니다.'),
          SizedBox(height: 4),
          Text('2) 이 앱에서 "애플 건강" 연동 버튼을 눌러 권한 요청 팝업에 동의합니다.'),
          SizedBox(height: 4),
          Text('3) 설정 > 건강 > 데이터 접근 및 기기에서 이 앱 권한을 켭니다.'),
          SizedBox(height: 4),
          Text('4) 연동 후 대시보드에서 걸음수/심박수 반영 여부를 확인합니다.'),
          SizedBox(height: 10),
          Text(
            '참고: 실제 자동 동기화는 iOS 빌드에서 HealthKit 권한 설정이 완료되어야 동작합니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
