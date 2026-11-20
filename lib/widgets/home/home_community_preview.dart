import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/offline_surah_names.dart';
import '../../models/tadabbur_note.dart';
import '../../theme/app_theme.dart';

/// Editorial unboxed Community Tadabbur preview with calm typography and left accent line.
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
            Expanded(
              child: Text(
                isThai ? 'ข้อคิดตะดับบุร' : 'Tadabbur & Reflections',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: appColors.foreground,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isThai ? 'ดูทั้งหมด' : 'View all',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: appColors.foreground,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: appColors.textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: appColors.primary,
                ),
              ),
            ),
          )
        else if (featuredNote == null)
          InkWell(
            onTap: onOpenEmpty ?? onViewAll,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: appColors.borderSoft),
                  bottom: BorderSide(color: appColors.borderSoft),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 20,
                    color: appColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isThai
                          ? 'แบ่งปันข้อคิดจากการอ่านอัลกุรอาน หรืออ่านบันทึกจากชุมชน'
                          : 'Share your Quran reflections or read community notes',
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
          )
        else
          _EditorialReflectionBlock(
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

class _EditorialReflectionBlock extends StatelessWidget {
  final TadabburNote note;
  final String translationText;
  final String authorName;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback? onTap;

  const _EditorialReflectionBlock({
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: appColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.format_quote_rounded,
                        size: 16,
                        color: appColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$surahName (${note.surahId}:${note.verseId})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: appColors.primary,
                            ),
                          ),
                          if (note.isQuranReflect)
                            Text(
                              '· QuranReflect EN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: appColors.mushafGold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_outline_rounded,
                          size: 14,
                          color: appColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${note.likesCount}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (translationText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    translationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: appColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  note.noteText.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13.5,
                    height: 1.45,
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
                          color: appColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      isThai ? 'อ่านต่อ →' : 'Read note →',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
