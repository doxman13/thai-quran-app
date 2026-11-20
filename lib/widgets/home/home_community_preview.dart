import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/offline_surah_names.dart';
import '../../models/tadabbur_note.dart';
import '../../theme/app_theme.dart';

/// Featured single-card Community Tadabbur preview (no shuffle clutter or hard shadows).
class HomeCommunityPreview extends StatelessWidget {
  final TadabburNote? featuredNote;
  final String translationText;
  final String authorName;
  final bool loading;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback onViewAll;
  final VoidCallback? onOpenEmpty;
  final ValueChanged<TadabburNote>? onOpenNote;

  const HomeCommunityPreview({
    super.key,
    required this.featuredNote,
    required this.translationText,
    required this.authorName,
    required this.loading,
    required this.isThai,
    required this.appColors,
    required this.onViewAll,
    this.onOpenEmpty,
    this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, size: 17, color: appColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isThai ? 'บันทึกตะดับบุรจากชุมชน' : 'Tadabbur Community',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onViewAll,
              icon: Text(
                isThai ? 'ดูทั้งหมด' : 'View all',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.primary,
                ),
              ),
              label: Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: appColors.primary,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          Container(
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: appColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: appColors.borderSoft),
            ),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: appColors.primary,
              ),
            ),
          )
        else if (featuredNote == null)
          Material(
            color: appColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: InkWell(
              onTap: onOpenEmpty ?? onViewAll,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: appColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rate_review_outlined, color: appColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isThai
                            ? 'แบ่งปันข้อคิดจากการอ่านอัลกุรอาน หรืออ่านบันทึกจากชุมชน'
                            : 'Share your Quran reflections or read notes from the community',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          color: appColors.foreground,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: appColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _FeaturedReflectionCard(
            note: featuredNote!,
            translationText: translationText,
            authorName: authorName,
            isThai: isThai,
            appColors: appColors,
            onTap: onOpenNote != null ? () => onOpenNote!(featuredNote!) : null,
          ),
      ],
    );
  }
}

class _FeaturedReflectionCard extends StatelessWidget {
  final TadabburNote note;
  final String translationText;
  final String authorName;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback? onTap;

  const _FeaturedReflectionCard({
    required this.note,
    required this.translationText,
    required this.authorName,
    required this.isThai,
    required this.appColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surahName = surahDisplayName(note.surahId, isThai: isThai);

    return Semantics(
      button: true,
      label: '$surahName ${note.surahId}:${note.verseId}, $authorName',
      child: Material(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: appColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: appColors.primaryLight,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              '$surahName (${note.surahId}:${note.verseId})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: appColors.primary,
                              ),
                            ),
                          ),
                          if (note.isQuranReflect)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: appColors.mushafGoldSoft,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Text(
                                'QuranReflect · EN',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: appColors.mushafGold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: appColors.mushafGold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${note.likesCount}',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (translationText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border(
                        left: BorderSide(color: appColors.primary, width: 3),
                      ),
                    ),
                    child: Text(
                      translationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: appColors.foreground,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  note.noteText.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    height: 1.4,
                    color: appColors.textStrong,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isThai ? 'โดย $authorName' : 'By $authorName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: appColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      isThai ? 'อ่านต่อ →' : 'Read note →',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: appColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
