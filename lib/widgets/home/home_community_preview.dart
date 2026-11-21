import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/offline_surah_names.dart';
import '../../models/tadabbur_note.dart';
import '../../providers/thai_text_protection_provider.dart';
import '../../theme/app_theme.dart';

/// Compact Community Tadabbur preview showing reference, one short excerpt,
/// author name, favourite count, and a clean read-more action.
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
                  fontSize: 16,
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
                minimumSize: const Size(44, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isThai ? 'ดูทั้งหมด' : 'View all',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
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
        const SizedBox(height: 6),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: appColors.primary,
                ),
              ),
            ),
          )
        else if (featuredNote == null)
          Material(
            color: appColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(
                color: appColors.borderSoft.withValues(alpha: 0.7),
              ),
            ),
            child: InkWell(
              onTap: onOpenEmpty ?? onViewAll,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 18,
                      color: appColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isThai
                            ? 'อ่านบันทึกข้อคิดตะดับบุรจากชุมชน'
                            : 'Explore community Tadabbur reflections',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: appColors.foreground,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: appColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _CompactReflectionCard(
            note: featuredNote!,
            authorName: authorName,
            isThai: isThai,
            appColors: appColors,
            onTap: onOpenNote != null ? () => onOpenNote!(featuredNote!) : null,
          ),
      ],
    );
  }
}

class _CompactReflectionCard extends StatelessWidget {
  final TadabburNote note;
  final String authorName;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback? onTap;

  const _CompactReflectionCard({
    required this.note,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(
            color: appColors.borderSoft.withValues(alpha: 0.7),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.isQuranReflect
                            ? '$surahName (${note.surahId}:${note.verseId}) · QuranReflect'
                            : '$surahName (${note.surahId}:${note.verseId})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: appColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_outline_rounded,
                          size: 13.5,
                          color: appColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${note.likesCount}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ThaiTextProtectionProvider.protectSafe(
                    context,
                    note.noteText.trim(),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  locale: ThaiTextProtectionProvider.localeForText(
                    note.noteText,
                    forceThai: isThai,
                  ),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    height: 1.4,
                    color: appColors.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isThai ? 'อ่านต่อ' : 'Read note',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: appColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: appColors.primary,
                        ),
                      ],
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
