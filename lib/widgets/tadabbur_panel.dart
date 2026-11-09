import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../models/tadabbur_note.dart';
import '../data/tadabbur_repository.dart';
import '../theme/app_theme.dart';
import '../shared/localization.dart';

class TadabburPanel extends StatefulWidget {
  final String surahId;
  final String verseId;
  final VoidCallback onClose;

  const TadabburPanel({
    super.key,
    required this.surahId,
    required this.verseId,
    required this.onClose,
  });

  @override
  State<TadabburPanel> createState() => _TadabburPanelState();
}

class _TadabburPanelState extends State<TadabburPanel> {
  final _repo = TadabburRepository();
  final _controller = TextEditingController();
  bool _isPublic = false;
  bool _isAnonymous = false;
  bool _isSaving = false;
  bool _saveSuccess = false;
  bool _isEditing = false;
  TadabburNote? _savedNote;
  String? _reviewStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() => _loading = true);
    final notesProv = context.read<NotesProvider>();
    final existing = notesProv.getNoteObjectForVerse(
      widget.surahId,
      widget.verseId,
    );

    String? status;
    if (existing != null) {
      try {
        final statuses = await _repo.fetchUserReviewStatuses();
        status = statuses[existing.id];
      } catch (_) {}
    }

    if (existing != null) {
      setState(() {
        _savedNote = existing;
        _reviewStatus = status;
        _controller.text = existing.noteText;
        _isPublic = existing.isPublic;
        _isAnonymous = existing.isAnonymous;
        _loading = false;
        if (existing.noteText.trim().isEmpty) {
          _isEditing = true;
        }
      });
    } else {
      setState(() {
        _reviewStatus = null;
        _isEditing = true;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();

    setState(() => _isSaving = true);
    final notesProv = context.read<NotesProvider>();
    final isAlreadyPublic = _savedNote?.isPublic ?? false;
    final shouldSubmitReview = _isPublic && text.isNotEmpty && !isAlreadyPublic;
    final isPublicToSave = isAlreadyPublic ? _isPublic : false;

    await notesProv.saveNote(
      surahId: widget.surahId,
      verseId: widget.verseId,
      noteText: text,
      isPublic: isPublicToSave,
      isAnonymous: _isAnonymous,
    );

    if (shouldSubmitReview) {
      final savedObj = notesProv.getNoteObjectForVerse(widget.surahId, widget.verseId);
      if (savedObj != null) {
        await _repo.submitForPublicReview(savedObj);
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      setState(() => _saveSuccess = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() => _saveSuccess = false);
          widget.onClose();
        }
      });
    }
  }

  Future<void> _delete() async {
    try {
      await context.read<NotesProvider>().deleteNote(
        widget.surahId,
        widget.verseId,
      );
      if (mounted) {
        setState(() => _savedNote = null);
        widget.onClose();
      }
    } catch (e) {
      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: colors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = settings.getAppColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isThai = settings.languageCode == 'th';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radius),
                  ),
                  border: Border(bottom: BorderSide(color: colors.borderSoft)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: colors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isThai
                          ? 'รายการโปรดและข้อคิด — อายะฮฺ ${widget.surahId}:${widget.verseId}'
                          : 'Favorite & Reflection — Ayah ${widget.surahId}:${widget.verseId}',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textStrong,
                      ),
                    ),
                    const Spacer(),
                    if (_savedNote != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _isEditing = !_isEditing),
                        icon: Icon(
                          _isEditing ? Icons.close : Icons.edit_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        label: Text(
                          _isEditing ? (isThai ? 'ยกเลิก' : 'Cancel') : (isThai ? 'แก้ไข' : 'Edit'),
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: colors.foreground.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_savedNote != null && !_isEditing)
                      ? _buildSavedCard(colors, isDark)
                      : _buildForm(colors, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedCard(AppThemeColors colors, bool isDark) {
    final hasNoteText = _savedNote!.noteText.isNotEmpty;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.background.withValues(alpha: 0.4)
                  : colors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSoft),
            ),
            child: hasNoteText
                ? Text(
                    _savedNote!.noteText,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.textStrong,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: colors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('favorited_no_reflection'),
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasNoteText) ...[
                _buildPrivacyChip(colors),
                const SizedBox(width: 8),
              ],
              Text(
                timeago.format(_savedNote!.updatedAt),
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (hasNoteText) ...[
                if (_savedNote!.isPublic)
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        final updated = await _repo.saveNote(
                          TadabburNote(
                            id: _savedNote!.id,
                            userId: _savedNote!.userId,
                            surahId: _savedNote!.surahId,
                            verseId: _savedNote!.verseId,
                            noteText: _savedNote!.noteText,
                            isPublic: false,
                            isAnonymous: _savedNote!.isAnonymous,
                            likesCount: _savedNote!.likesCount,
                            language: _savedNote!.language,
                            createdAt: _savedNote!.createdAt,
                            updatedAt: DateTime.now(),
                            synced: true,
                          ),
                        );
                        await _repo.cancelReviewRequest(_savedNote!.id);
                        if (updated != null && mounted) {
                          setState(() {
                            _savedNote = updated;
                            _reviewStatus = null;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: colors.danger,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.lock_outline_rounded, size: 14),
                    label: Text(
                      isThai ? 'ทำให้เป็นส่วนตัว' : 'Make Private',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else if (_reviewStatus == 'open' || _reviewStatus == 'reviewing')
                  TextButton.icon(
                    onPressed: () async {
                      await _repo.cancelReviewRequest(_savedNote!.id);
                      if (mounted) {
                        setState(() => _reviewStatus = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ยกเลิกคำขอตรวจสอบแล้ว')),
                        );
                      }
                    },
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: Text(
                      isThai ? 'ยกเลิกคำขอตรวจสอบ' : 'Cancel Review',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.danger,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            isThai ? 'ส่งให้แอดมินตรวจสอบ' : 'Submit for Review',
                            style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            isThai
                                ? 'ต้องการส่งบันทึกนี้ให้แอดมินตรวจสอบเพื่อแชร์สู่ชุมชนใช่หรือไม่?'
                                : 'Do you want to submit this reflection to admins for community review?',
                            style: GoogleFonts.notoSansThai(fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                isThai ? 'ยกเลิก' : 'Cancel',
                                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                isThai ? 'ส่งตรวจสอบ' : 'Submit',
                                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await _repo.submitForPublicReview(_savedNote!);
                          if (mounted) {
                            setState(() => _reviewStatus = 'open');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ส่งบันทึกให้แอดมินตรวจสอบเรียบร้อยแล้ว'),
                                backgroundColor: Color(0xFF0E5A4A),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: colors.danger),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.public_rounded, size: 14),
                    label: Text(
                      isThai ? 'ส่งแชร์สู่ชุมชน' : 'Share to Community',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: colors.danger,
                ),
                tooltip: context.tr('unfavorite'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        context.tr('remove_from_favorites'),
                        style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
                      ),
                      content: Text(
                        context.tr('unfavorite_confirm'),
                        style: GoogleFonts.notoSansThai(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            context.tr('cancel'),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            context.tr('unfavorite'),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              color: colors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await _delete();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyChip(AppThemeColors colors) {
    final isPublic = _savedNote?.isPublic ?? _isPublic;
    final isPending = _reviewStatus == 'open' || _reviewStatus == 'reviewing';
    final isRejected = _reviewStatus == 'rejected';
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';

    final chipColor = isPublic
        ? colors.success
        : isPending
        ? const Color(0xFFB45309)
        : isRejected
        ? colors.danger
        : colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic
                ? Icons.public
                : isPending
                ? Icons.hourglass_top_rounded
                : isRejected
                ? Icons.cancel_outlined
                : Icons.lock_outline,
            size: 11,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic
                ? (isThai ? 'สาธารณะ' : 'Public')
                : isPending
                ? (isThai ? 'รอตรวจสอบ' : 'In Review')
                : isRejected
                ? (isThai ? 'ไม่อนุมัติ' : 'Rejected')
                : (isThai ? 'ส่วนตัว' : 'Private'),
            style: GoogleFonts.notoSansThai(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppThemeColors colors, bool isDark) {
    final isTextEmpty = _controller.text.trim().isEmpty;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';
    final buttonLabel = _saveSuccess
        ? (isThai ? 'บันทึกสำเร็จแล้ว' : 'Saved successfully')
        : isTextEmpty
        ? (isThai ? 'บันทึกเป็นรายการโปรด' : 'Save as Favorite')
        : (isThai ? 'บันทึกรายการโปรดและโน้ต' : 'Save Favorite & Note');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 15,
                color: colors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                isThai ? 'บันทึกใคร่ครวญ (ไม่บังคับ)' : 'Reflection Note (Optional)',
                style: GoogleFonts.notoSansThai(
                  color: colors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 10,
            style: GoogleFonts.notoSansThai(fontSize: 15, color: colors.textStrong),
            decoration: InputDecoration(
              hintText: isThai ? 'เขียนข้อคิดหรือใคร่ครวญที่นี่ (ไม่บังคับ)...' : 'Write your reflection here (optional)...',
              hintStyle: GoogleFonts.notoSansThai(
                fontSize: 14,
                color: colors.foreground.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: isDark
                  ? colors.background.withValues(alpha: 0.4)
                  : colors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.borderSoft, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!isTextEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 15,
                  color: colors.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  isThai ? 'การมองเห็น' : 'Visibility',
                  style: GoogleFonts.notoSansThai(
                    color: colors.textStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.background.withValues(alpha: 0.5)
                    : colors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPublic = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isPublic
                              ? (isDark
                                    ? colors.primary.withValues(alpha: 0.2)
                                    : colors.primary)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: !_isPublic
                                  ? (isDark
                                        ? colors.primary
                                        : colors.textInverse)
                                  : colors.foreground.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isThai ? 'ส่วนตัว' : 'Private',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: !_isPublic
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: !_isPublic
                                    ? (isDark
                                          ? colors.primary
                                          : colors.textInverse)
                                    : colors.foreground.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPublic = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isPublic
                              ? (isDark
                                    ? colors.primary.withValues(alpha: 0.2)
                                    : colors.primary)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 14,
                              color: _isPublic
                                  ? (isDark
                                        ? colors.primary
                                        : colors.textInverse)
                                  : colors.foreground.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isThai ? 'สาธารณะ' : 'Public',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: _isPublic
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _isPublic
                                    ? (isDark
                                          ? colors.primary
                                          : colors.textInverse)
                                    : colors.foreground.withValues(alpha: 0.8),
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
            if (_isPublic)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isThai
                      ? '💡 การแชร์สู่สาธารณะจะถูกส่งให้ทีมงานตรวจสอบก่อนเผยแพร่'
                      : '💡 Public reflections are reviewed by moderators before appearing in community',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    color: const Color(0xFF8A6530),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isTextEmpty
                    ? colors.danger
                    : colors.primary,
                foregroundColor: colors.textInverse,
                disabledBackgroundColor:
                    (isTextEmpty ? colors.danger : colors.primary)
                        .withValues(alpha: 0.25),
                disabledForegroundColor: colors.textInverse.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              onPressed: _isSaving || _saveSuccess ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _saveSuccess
                          ? Icons.check_circle_outline_rounded
                          : isTextEmpty
                          ? Icons.favorite_rounded
                          : Icons.save_rounded,
                      size: 16,
                    ),
              label: Text(
                buttonLabel,
                style: GoogleFonts.notoSansThai(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
