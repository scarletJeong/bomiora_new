import 'package:flutter/material.dart';
import '../widget/contact_inquiry_type_filters.dart';
import 'contact_form_screen.dart';
import 'contact_detail_screen.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/contact_service.dart';

/// 1:1 문의 **화면(페이지)** — 앱바, 총 문의수, 문의유형 필터, 목록.
class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _contactCount = 0;
  /// 목록에 표시할 최대 개수(더보기/8개 단위 확장).
  int _visibleCount = 8;

  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kCardBorder = Color(0x7FD2D2D2);
  static const Color _kDateColor = Color(0xFF584045);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contacts = await ContactService.getMyContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _contactCount = contacts.length;
        _visibleCount = contacts.length < 8 ? contacts.length : 8;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '문의내역을 불러오는데 실패했습니다: $e';
        _isLoading = false;
        _contactCount = 0;
      });
    }
  }

  Future<void> _openContactForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactFormScreen(),
      ),
    );
    if (result == true) _loadContacts();
  }

  String _statusLabel(Contact contact) {
    return contact.hasReply ? '답변완료' : '접수완료';
  }

  String _formatDate(String datetime) {
    try {
      final date = DateTime.parse(datetime);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return datetime;
    }
  }

  Widget _buildCountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: _kBorder,
        ),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '총 문의수 ',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$_contactCount',
                style: const TextStyle(
                  color: _kPink,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          height: 1,
          color: _kBorder,
        ),
      ],
    );
  }

  Widget _buildContactItem(BuildContext context, Contact contact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactDetailScreen(wrId: contact.wrId),
            ),
          ).then((_) => _loadContacts());
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kCardBorder),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(contact.wrDatetime),
                      style: const TextStyle(
                        color: _kDateColor,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.wrSubject.isEmpty ? '(제목 없음)' : contact.wrSubject,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.44,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel(contact),
                      style: const TextStyle(
                        color: _kMuted,
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.08,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF3787)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontFamily: 'Gmarket Sans TTF',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadContacts,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(27, 0, 27, 100),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '문의내역이 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Gmarket Sans TTF',
              ),
            ),
          ],
        ),
      );
    }

    final total = _contacts.length;
    final shown = _visibleCount > total ? total : _visibleCount;
    final hasMore = shown < total;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(27, 0, 27, 100),
      itemCount: shown + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == shown && hasMore) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _visibleCount = (_visibleCount + 8 > total) ? total : _visibleCount + 8;
                  });
                },
                child: const Text(
                  '더보기',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }
        return _buildContactItem(context, _contacts[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'Gmarket Sans TTF',
        color: Color(0xFF1A1A1A),
      ),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(
          title: '1:1 문의',
        ),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 27, right: 27),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildCountRow(),
                    const SizedBox(height: 20),
                    const ContactInquiryTypeFilters(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Expanded(child: _buildListBody()),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(27, 8, 27, 12),
                child: GestureDetector(
                  onTap: _openContactForm,
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    padding: const EdgeInsets.all(10),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '1:1 문의하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
