import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/models/health/weight_record_model.dart';
import 'weight_input_screen.dart';

class WeightListScreen extends StatefulWidget {
  const WeightListScreen({super.key});

  @override
  State<WeightListScreen> createState() => _WeightListScreenState();
}

class _WeightListScreenState extends State<WeightListScreen> {
  List<WeightRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeightRecords();
  }

  Future<void> _loadWeightRecords() async {
    setState(() => _isLoading = true);

    try {
      // TODO: API 호출로 데이터 가져오기
      // final response = await ApiClient.get('/api/health/weight');
      
      // 임시 더미 데이터
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _records = [
          WeightRecord(
            id: 1,
            mbNo: 123,
            measuredAt: DateTime.now(),
            weight: 65.5,
            height: 170.0,
            bmi: WeightRecord.calculateBMI(65.5, 170.0),
            notes: '아침 측정',
          ),
          WeightRecord(
            id: 2,
            mbNo: 123,
            measuredAt: DateTime.now().subtract(const Duration(days: 1)),
            weight: 65.8,
            height: 170.0,
            bmi: WeightRecord.calculateBMI(65.8, 170.0),
          ),
          WeightRecord(
            id: 3,
            mbNo: 123,
            measuredAt: DateTime.now().subtract(const Duration(days: 2)),
            weight: 66.0,
            height: 170.0,
            bmi: WeightRecord.calculateBMI(66.0, 170.0),
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('체중 기록 로딩 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToInput({WeightRecord? record}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightInputScreen(record: record),
      ),
    );

    if (result == true) {
      _loadWeightRecords(); // 새로고침
    }
  }

  Future<void> _deleteRecord(WeightRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${DateFormat('M월 d일').format(record.measuredAt)} 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // TODO: API 호출로 삭제
        // await ApiClient.delete('/api/health/weight/${record.id}');
        
        setState(() {
          _records.removeWhere((r) => r.id == record.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기록이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text('체중 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeightRecords,
          ),
        ],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_weight_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '체중 기록이 없습니다',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '첫 번째 기록을 추가해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            const Text(
              '기록 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._records.map((record) => _buildRecordCard(record)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _navigateToInput(),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (_records.isEmpty) return const SizedBox.shrink();

    final latest = _records.first;
    final oldest = _records.last;
    final weightChange = latest.weight - oldest.weight;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 체중',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${latest.weight}',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const Text(
                  ' kg',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 16),
                if (latest.bmi != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BMI ${latest.bmi}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        latest.bmiStatus,
                        style: TextStyle(
                          fontSize: 14,
                          color: _getBmiColor(latest.bmi),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (_records.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    weightChange > 0
                        ? Icons.arrow_upward
                        : weightChange < 0
                            ? Icons.arrow_downward
                            : Icons.remove,
                    size: 16,
                    color: weightChange > 0
                        ? Colors.red
                        : weightChange < 0
                            ? Colors.green
                            : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)}kg',
                    style: TextStyle(
                      fontSize: 14,
                      color: weightChange > 0
                          ? Colors.red
                          : weightChange < 0
                              ? Colors.green
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_records.length}일간)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(WeightRecord record) {
    final dateFormat = DateFormat('M월 d일 (E)', 'ko');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.monitor_weight, color: Colors.blue[700]),
        ),
        title: Row(
          children: [
            Text(
              '${record.weight}kg',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (record.bmi != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getBmiColor(record.bmi).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'BMI ${record.bmi}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getBmiColor(record.bmi),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dateFormat.format(record.measuredAt)} ${timeFormat.format(record.measuredAt)}'),
            if (record.notes != null && record.notes!.isNotEmpty)
              Text(
                record.notes!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _navigateToInput(record: record);
            } else if (value == 'delete') {
              _deleteRecord(record);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('수정'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('삭제', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBmiColor(double? bmi) {
    if (bmi == null) return Colors.grey;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 23) return Colors.green;
    if (bmi < 25) return Colors.orange;
    return Colors.red;
  }
}

