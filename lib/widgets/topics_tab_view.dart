import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_quran_database_service.dart';
import '../screens/topic_verses_screen.dart';

class TopicsTabView extends StatefulWidget {
  final String? externalSearchQuery;
  final ValueChanged<String>? onSearchChanged;

  const TopicsTabView({
    super.key,
    this.externalSearchQuery,
    this.onSearchChanged,
  });

  @override
  State<TopicsTabView> createState() => _TopicsTabViewState();
}

class _TopicsTabViewState extends State<TopicsTabView> {
  List<Map<String, dynamic>> _categories = [];
  Map<int, List<Map<String, dynamic>>> _topicsByCategory = {};
  bool _isLoading = true;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.externalSearchQuery ?? '');
    _loadData();
  }

  @override
  void didUpdateWidget(covariant TopicsTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalSearchQuery != null &&
        widget.externalSearchQuery != _searchController.text) {
      _searchController.text = widget.externalSearchQuery!;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cats = await OfflineQuranDatabaseService.getTopicCategories();
    final topicsMap = <int, List<Map<String, dynamic>>>{};
    for (final cat in cats) {
      final catId = cat['id'] as int;
      final topics = await OfflineQuranDatabaseService.getTopicsForCategory(catId);
      topicsMap[catId] = topics;
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        _topicsByCategory = topicsMap;
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'history_edu':
        return Icons.auto_stories_rounded;
      case 'volunteer_activism':
        return Icons.volunteer_activism_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'family_restroom':
        return Icons.family_restroom_rounded;
      case 'nature_people':
        return Icons.eco_rounded;
      default:
        return Icons.topic_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _searchController.text.trim().toLowerCase();

    // Check if any topics matched across all categories
    int totalMatchingTopics = 0;
    for (final cat in _categories) {
      final catId = cat['id'] as int;
      final catTitleTh = (cat['title_th'] as String? ?? '').toLowerCase();
      final allTopics = _topicsByCategory[catId] ?? [];
      final matches = query.isEmpty
          ? allTopics
          : allTopics.where((t) {
              final th = (t['title_th'] as String? ?? '').toLowerCase();
              final en = (t['title_en'] as String? ?? '').toLowerCase();
              return catTitleTh.contains(query) || th.contains(query) || en.contains(query);
            }).toList();
      totalMatchingTopics += matches.length;
    }

    return Column(
      children: [
        // Internal Search bar if not provided from parent
        if (widget.externalSearchQuery == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {});
                widget.onSearchChanged?.call(val);
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาหัวข้อ (เช่น นบี, ละหมาด, พ่อแม่, สวรรค์)...',
                hintStyle: GoogleFonts.notoSansThai(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          widget.onSearchChanged?.call('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),

        // List of categories & topics
        Expanded(
          child: query.isNotEmpty && totalMatchingTopics == 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ไม่พบหัวข้อที่ตรงกับ "$query"',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ลองค้นหาด้วยคำสำคัญอื่น เช่น นบี, ละหมาด, ความอดทน, วันสิ้นโลก',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, catIndex) {
                    final cat = _categories[catIndex];
                    final catId = cat['id'] as int;
                    final catTitleTh = cat['title_th'] as String? ?? '';
                    final catTitleEn = cat['title_en'] as String? ?? '';
                    final iconName = cat['icon_name'] as String? ?? '';
                    final allTopics = _topicsByCategory[catId] ?? [];

                    final catMatches = catTitleTh.toLowerCase().contains(query);

                    final filteredTopics = query.isEmpty
                        ? allTopics
                        : allTopics.where((t) {
                            final th = (t['title_th'] as String? ?? '').toLowerCase();
                            final en = (t['title_en'] as String? ?? '').toLowerCase();
                            return catMatches || th.contains(query) || en.contains(query);
                          }).toList();

                    if (query.isNotEmpty && filteredTopics.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Category Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(iconName),
                                    color: colorScheme.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        catTitleTh,
                                        style: GoogleFonts.notoSansThai(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        catTitleEn,
                                        style: GoogleFonts.notoSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${filteredTopics.length} หัวข้อ',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),

                          // Topic Items
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredTopics.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              indent: 56,
                              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                            ),
                            itemBuilder: (context, tIndex) {
                              final topic = filteredTopics[tIndex];
                              final topicId = topic['id'] as int;
                              final topicTitleTh = topic['title_th'] as String? ?? '';
                              final topicTitleEn = topic['title_en'] as String? ?? '';
                              final versesCount = topic['verses_count'] as int? ?? 0;

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TopicVersesScreen(
                                        topicId: topicId,
                                        topicTitleTh: topicTitleTh,
                                        topicTitleEn: topicTitleEn,
                                        versesCount: versesCount,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: tIndex == filteredTopics.length - 1
                                    ? const BorderRadius.vertical(bottom: Radius.circular(20))
                                    : BorderRadius.zero,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${tIndex + 1}',
                                            style: GoogleFonts.notoSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              topicTitleTh,
                                              style: GoogleFonts.notoSansThai(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              topicTitleEn,
                                              style: GoogleFonts.notoSans(
                                                fontSize: 11.5,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$versesCount อายะฮ์',
                                          style: GoogleFonts.notoSansThai(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
