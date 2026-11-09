import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../data/tadabbur_repository.dart';
import '../data/quran_repository.dart';
import '../data/offline_surah_names.dart';
import '../data/medina_mushaf_pages.dart';
import '../shared/shared.dart';
import 'mushaf_reader_screen.dart';
import '../data/quran_foundation_repository.dart';

class TadabburAdminScreen extends StatefulWidget {
  final QuranRepository repository;

  const TadabburAdminScreen({super.key, required this.repository});

  @override
  State<TadabburAdminScreen> createState() => _TadabburAdminScreenState();
}

class _TadabburAdminScreenState extends State<TadabburAdminScreen> {
  final _repo = TadabburRepository();
  final _foundationRepo = QuranFoundationRepository();

  bool _isAuthenticated = false;
  bool _loading = false;
  String _passphraseInput = '';
  String? _authError;

  List<Map<String, dynamic>> _items = [];
  String _activeTab = 'pending'; // 'pending' | 'accepted' | 'rejected' | 'all'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (TadabburRepository.cachedAdminPassphrase != null) {
      _isAuthenticated = true;
      _loadItems();
    }
  }

  Future<void> _verifyPassphrase() async {
    final candidate = _passphraseInput.trim();
    if (candidate.isEmpty) {
      setState(() => _authError = 'กรุณากรอกรหัสผ่าน');
      return;
    }

    setState(() {
      _loading = true;
      _authError = null;
    });

    final isValid = await _repo.verifyAdminPassphrase(candidate);
    if (!mounted) return;

    if (isValid) {
      TadabburRepository.setAdminPassphrase(candidate);
      setState(() {
        _isAuthenticated = true;
        _loading = false;
      });
      _loadItems();
    } else {
      setState(() {
        _loading = false;
        _authError = 'รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง';
      });
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final results = await _repo.fetchAdminReviewRequests();
    if (mounted) {
      setState(() {
        _items = results;
        _loading = false;
      });
    }
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final reportId = item['id']?.toString() ?? '';
    final noteId = item['noteId']?.toString() ?? '';
    if (reportId.isEmpty || noteId.isEmpty) return;

    final success = await _repo.approveTadabburNote(reportId, noteId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อนุมัติบันทึกเรียบร้อยแล้ว บันทึกนี้แสดงสู่สาธารณะแล้ว'),
            backgroundColor: Color(0xFF0E5A4A),
          ),
        );
        _loadItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการอนุมัติ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _promptReject(Map<String, dynamic> item) async {
    final reportId = item['id']?.toString() ?? '';
    final noteId = item['noteId']?.toString() ?? '';
    if (reportId.isEmpty || noteId.isEmpty) return;

    final controller = TextEditingController(text: item['reviewerNote']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ไม่อนุมัติบันทึกตดับบุร',
          style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ซูเราะฮฺ ${item['surahId']}:${item['verseId']}',
              style: GoogleFonts.notoSansThai(
                fontSize: 12,
                color: const Color(0xFF0E5A4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ระบุเหตุผลหรือข้อแนะนำ (ไม่บังคับ):',
              style: GoogleFonts.notoSansThai(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              style: GoogleFonts.notoSansThai(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'เช่น ข้อความไม่สอดคล้องกับอายะฮฺ...',
                hintStyle: GoogleFonts.notoSansThai(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'ยกเลิก',
              style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'ยืนยันไม่อนุมัติ',
              style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _repo.rejectTadabburNote(
        reportId,
        noteId,
        reviewerNote: controller.text.trim().isEmpty ? null : controller.text.trim(),
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกสถานะไม่อนุมัติเรียบร้อยแล้ว'),
            ),
          );
          _loadItems();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เกิดข้อผิดพลาด'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((it) {
      final status = it['status']?.toString() ?? 'open';
      if (_activeTab == 'pending' && status != 'open' && status != 'reviewing') {
        return false;
      }
      if (_activeTab == 'accepted' && status != 'accepted') {
        return false;
      }
      if (_activeTab == 'rejected' && status != 'rejected') {
        return false;
      }

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final surah = it['surahId']?.toString() ?? '';
      final verse = it['verseId']?.toString() ?? '';
      final text = (it['noteText']?.toString() ?? '').toLowerCase();
      return '$surah:$verse'.contains(q) || text.contains(q);
    }).toList();
  }

  int get _pendingCount =>
      _items.where((it) => it['status'] == 'open' || it['status'] == 'reviewing').length;
  int get _acceptedCount =>
      _items.where((it) => it['status'] == 'accepted').length;
  int get _rejectedCount =>
      _items.where((it) => it['status'] == 'rejected').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F5),
      appBar: AppBar(
        title: Text(
          'ตรวจสอบตดับบุร (Admin)',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFF0E5A4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'รีเฟรชข้อมูล',
              onPressed: _loadItems,
            ),
        ],
      ),
      body: !_isAuthenticated ? _buildAuthForm() : _buildDashboard(),
    );
  }

  Widget _buildAuthForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFF0E5A4A),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'เข้าสู่ระบบผู้ดูแล',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'กรุณากรอกรหัสผ่านเพื่อเข้าใช้งานระบบตรวจสอบการใคร่ครวญ (Tadabbur Moderation)',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  obscureText: true,
                  onChanged: (val) => _passphraseInput = val,
                  onSubmitted: (_) => _verifyPassphrase(),
                  style: GoogleFonts.notoSansThai(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'รหัสผ่านผู้ดูแลระบบ (Admin Passphrase)',
                    hintStyle: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      color: const Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                if (_authError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _authError!,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyPassphrase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E5A4A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'เข้าสู่ระบบ',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final filtered = _filteredItems;

    return Column(
      children: [
        // Top Filtering Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // Search input
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.notoSansThai(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ค้นหาด้วยเลขซูเราะฮฺ:อายะฮฺ หรือข้อความ...',
                  hintStyle: GoogleFonts.notoSansThai(fontSize: 12, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              // Tab pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabPill('pending', 'รอตรวจสอบ ($_pendingCount)'),
                    const SizedBox(width: 8),
                    _buildTabPill('accepted', 'อนุมัติแล้ว ($_acceptedCount)'),
                    const SizedBox(width: 8),
                    _buildTabPill('rejected', 'ไม่อนุมัติ ($_rejectedCount)'),
                    const SizedBox(width: 8),
                    _buildTabPill('all', 'ทั้งหมด (${_items.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0E5A4A),
                  ),
                )
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'ไม่พบบันทึกในหมวดนี้',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  color: const Color(0xFF0E5A4A),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildItemCard(filtered[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTabPill(String tabKey, String label) {
    final isActive = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0E5A4A) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansThai(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final surahId = item['surahId']?.toString() ?? '1';
    final verseId = item['verseId']?.toString() ?? '1';
    final noteText = item['noteText']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'open';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';
    final isPending = status == 'open' || status == 'reviewing';
    final reviewerNote = item['reviewerNote']?.toString();
    final surahName = widget.repository
        .getSurahName(surahId)
        .replaceAll(RegExp(r'^\d+\.\s*'), '');
    final surahAr = offlineSurahNamesAr[surahId];
    final verseObj = widget.repository.getVerse(surahId, verseId);
    final translationText = resolveVerseTranslationText(
      context: context,
      verseKey: '$surahId:$verseId',
      verse: verseObj,
    );
    final createdAtStr = item['createdAt']?.toString();
    final createdTime = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2EE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$surahName ($surahId:$verseId)',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0E5A4A),
                        ),
                      ),
                    ),
                    if (surahAr != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        surahAr,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 14,
                          color: Color(0xFF0E5A4A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status Pill
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'รอตรวจสอบ',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                )
              else if (isAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'อนุมัติแล้ว',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF047857),
                    ),
                  ),
                )
              else if (isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'ไม่อนุมัติ',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB91C1C),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Quran Context Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Arabic
                FutureBuilder<String>(
                  future: widget.repository.fetchArabicVerse(surahId, verseId),
                  builder: (context, snapshot) {
                    final ar = snapshot.data;
                    if (ar == null || ar.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ar,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 16,
                          height: 2.0,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    );
                  },
                ),
                // Thai Translation
                if (translationText.isNotEmpty)
                  Text(
                    translationText,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: const Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // User Reflection Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF9F5),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: Color(0xFF0E5A4A), width: 3),
              ),
            ),
            child: Text(
              noteText.isNotEmpty ? noteText : '(ไม่มีข้อความบันทึก)',
              style: GoogleFonts.notoSansThai(
                fontSize: 13,
                height: 1.6,
                color: const Color(0xFF111827),
              ),
            ),
          ),

          if (reviewerNote != null && reviewerNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'หมายเหตุผู้ตรวจ: $reviewerNote',
              style: GoogleFonts.notoSansThai(
                fontSize: 11,
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Footer meta & Action Buttons
          Row(
            children: [
              if (createdTime != null)
                Text(
                  timeago.format(createdTime),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              const Spacer(),
              // Reader shortcut
              IconButton(
                icon: const Icon(Icons.menu_book, size: 16, color: Color(0xFF8A6530)),
                tooltip: 'เปิดในมุศหัฟ',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final sId = int.tryParse(surahId) ?? 1;
                  final vId = int.tryParse(verseId) ?? 1;
                  final page = getMedinaMushafPageNumber(sId, vId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MushafReaderScreen(
                        quranRepository: widget.repository,
                        foundationRepository: _foundationRepo,
                        initialPage: page,
                        initialHighlightVerseKey: '$sId:$vId',
                      ),
                    ),
                  );
                },
              ),
              // Approve button
              ElevatedButton.icon(
                onPressed: isAccepted ? null : () => _approve(item),
                icon: const Icon(Icons.check, size: 14),
                label: Text(
                  isAccepted ? 'อนุมัติแล้ว' : 'อนุมัติ',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E5A4A),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Reject button
              OutlinedButton.icon(
                onPressed: () => _promptReject(item),
                icon: const Icon(Icons.close, size: 14),
                label: Text(
                  isRejected ? 'แก้เหตุผล' : 'ไม่อนุมัติ',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
