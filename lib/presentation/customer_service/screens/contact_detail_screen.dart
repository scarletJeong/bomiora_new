import 'package:flutter/material.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/contact_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class ContactDetailScreen extends StatefulWidget {
  final int wrId;

  const ContactDetailScreen({
    super.key,
    required this.wrId,
  });

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  Contact? _contact;
  List<Contact> _replies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContactDetail();
  }

  Future<void> _loadContactDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contact = await ContactService.getContactDetail(widget.wrId);
      if (contact != null) {
        setState(() {
          _contact = contact;
          _isLoading = false;
        });
        
        // 항상 답변 목록 로드 시도 (wr_comment가 업데이트되지 않을 수 있음)
        _loadReplies();
      } else {
        setState(() {
          _errorMessage = '문의를 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '문의를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReplies() async {
    try {
      print('💬 [답변 로드] wr_id: ${widget.wrId}');
      final replies = await ContactService.getContactReplies(widget.wrId);
      print('💬 [답변 로드] 답변 개수: ${replies.length}');
      
      if (mounted) {
        setState(() {
          _replies = replies;
        });
      }
      
      if (replies.isNotEmpty) {
        print('✅ [답변 로드] 답변 표시 완료');
      } else {
        print('⚠️ [답변 로드] 답변 없음 (아직 답변이 달리지 않았거나 DB에 없음)');
      }
    } catch (e) {
      print('❌ [답변 로드] 실패: $e');
      // 답변 로드 실패는 무시 (문의 자체는 표시)
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '문의 상세',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadContactDetail,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _contact == null
                  ? const Center(child: Text('문의를 찾을 수 없습니다.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 문의 제목
                          Text(
                            _contact!.wrSubject,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // 문의 정보
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _contact!.wrName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(_contact!.wrDatetime),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${_contact!.wrHit}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          const Divider(),
                          const SizedBox(height: 16),
                          
                          // 문의 내용
                          Text(
                            '문의 내용',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              _contact!.getPlainTextContent(), // HTML 파싱하여 순수 텍스트만 표시
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.6,
                              ),
                            ),
                          ),
                          
                          // 답변 표시 (실제 답변 배열로 판단)
                          if (_replies.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              '답변',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // 답변 목록
                            ..._replies.map((reply) => _buildReplyCard(reply)),
                          ] else ...[
                            const SizedBox(height: 32),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    '답변 대기 중입니다.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildReplyCard(Contact reply) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
              const SizedBox(width: 4),
              Text(
                '관리자 답변',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(reply.wrDatetime),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reply.getPlainTextContent(), // HTML 파싱하여 순수 텍스트만 표시
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String datetime) {
    try {
      final date = DateTime.parse(datetime);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return datetime;
    }
  }
}

