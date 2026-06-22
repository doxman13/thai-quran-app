import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../models/tadabbur_note.dart';
import '../data/tadabbur_repository.dart';

class TadabburPanel extends StatefulWidget {
  final String surahId;
  final String verseId;
  final VoidCallback onClose;

  const TadabburPanel({
    Key? key,
    required this.surahId,
    required this.verseId,
    required this.onClose,
  }) : super(key: key);

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
    final existing = notesProv.getNoteObjectForVerse(widget.surahId, widget.verseId);
    if (existing != null) {
      setState(() {
        _savedNote = existing;
        _controller.text = existing.noteText;
        _isPublic = existing.isPublic;
        _isAnonymous = existing.isAnonymous;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    final notesProv = context.read<NotesProvider>();
    await notesProv.saveNote(
      surahId: widget.surahId,
      verseId: widget.verseId,
      noteText: text,
      isPublic: _isPublic,
      isAnonymous: _isAnonymous,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (text.isNotEmpty) {
        setState(() => _saveSuccess = true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            setState(() => _saveSuccess = false);
            widget.onClose();
          }
        });
      } else {
        widget.onClose();
      }
    }
  }

  Future<void> _delete() async {
    try {
      await _repo.deleteNote(_savedNote!.id);
      if (mounted) {
        setState(() => _savedNote = null);
        widget.onClose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.getPrimaryColor();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Text(
                  'Tadabbur — ${widget.surahId}:${widget.verseId}',
                  style: GoogleFonts.prompt(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                if (_savedNote != null)
                  TextButton(
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    child: Text(
                      _isEditing ? 'Cancel' : 'Edit',
                      style: GoogleFonts.prompt(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Body
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_savedNote != null && !_isEditing)
            _buildSavedCard(primaryColor, isDark)
          else
            _buildForm(primaryColor, isDark),
        ],
      ),
    );
  }

  Widget _buildSavedCard(Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _savedNote!.noteText,
            style: GoogleFonts.prompt(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            timeago.format(_savedNote!.updatedAt),
            style: GoogleFonts.prompt(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPrivacyChip(primaryColor),
              const Spacer(),
              if (_savedNote!.isPublic)
                TextButton(
                  onPressed: () async {
                    try {
                      final updated = await _repo.saveNote(TadabburNote(
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
                      ));
                      if (updated != null && mounted) {
                        setState(() => _savedNote = updated);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Text('Make Private', style: GoogleFonts.prompt(fontSize: 10)),
                )
              else
                TextButton(
                  onPressed: () async {
                    try {
                      final updated = await _repo.saveNote(TadabburNote(
                        id: _savedNote!.id,
                        userId: _savedNote!.userId,
                        surahId: _savedNote!.surahId,
                        verseId: _savedNote!.verseId,
                        noteText: _savedNote!.noteText,
                        isPublic: true,
                        isAnonymous: _savedNote!.isAnonymous,
                        likesCount: _savedNote!.likesCount,
                        language: _savedNote!.language,
                        createdAt: _savedNote!.createdAt,
                        updatedAt: DateTime.now(),
                        synced: true,
                      ));
                      if (updated != null && mounted) {
                        setState(() => _savedNote = updated);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Text('Make Public', style: GoogleFonts.prompt(fontSize: 10)),
                ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete?', style: GoogleFonts.prompt(fontWeight: FontWeight.bold)),
                      content: Text('Delete this reflection?', style: GoogleFonts.prompt()),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.prompt())),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.prompt(color: Colors.red))),
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

  Widget _buildPrivacyChip(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _isPublic ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPublic ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPublic ? Icons.public : Icons.lock_outline,
            size: 10,
            color: _isPublic ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            _isPublic ? 'Public' : 'Private',
            style: GoogleFonts.prompt(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            style: GoogleFonts.prompt(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Write your reflection...',
              hintStyle: GoogleFonts.prompt(fontSize: 12, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _isPublic,
                onChanged: (val) => setState(() => _isPublic = val),
                activeColor: primaryColor,
              ),
              Text('Public', style: GoogleFonts.prompt(fontSize: 11)),
              const SizedBox(width: 12),
              Switch(
                value: _isAnonymous,
                onChanged: (val) => setState(() => _isAnonymous = val),
                activeColor: primaryColor,
              ),
              Text('Anonymous', style: GoogleFonts.prompt(fontSize: 11)),
              const Spacer(),
              ElevatedButton(
                onPressed: _isSaving || _saveSuccess || _controller.text.trim().isEmpty ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _saveSuccess ? 'Saved ✓' : 'Save',
                        style: GoogleFonts.prompt(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
