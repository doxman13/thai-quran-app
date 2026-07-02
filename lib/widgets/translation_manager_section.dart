import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/settings_provider.dart';
import '../providers/translation_manager_provider.dart';
import '../services/translation_downloader.dart';
import '../theme/app_theme.dart';

class TranslationManagerSection extends StatefulWidget {
  final AppThemeColors colors;
  const TranslationManagerSection({Key? key, required this.colors}) : super(key: key);

  @override
  State<TranslationManagerSection> createState() => _TranslationManagerSectionState();
}

class _TranslationManagerSectionState extends State<TranslationManagerSection> {
  // Hardcoded available translations as per user request
  final List<Map<String, dynamic>> _availableTranslations = [
    {'id': 20, 'name': 'Saheeh International', 'author': 'Saheeh International', 'language': 'English'},
    {'id': 85, 'name': 'M.A.S. Abdel Haleem', 'author': 'Abdul Haleem', 'language': 'English'},
    {'id': 84, 'name': 'T. Usmani', 'author': 'Mufti Taqi Usmani', 'language': 'English'},
    {'id': 39, 'name': 'Abdullah Muhammad Basmeih', 'author': 'Abdullah Muhammad Basmeih', 'language': 'Malay'},
    {'id': 230, 'name': 'Society of Institutes', 'author': 'Society of Institutes', 'language': 'Thai'},
    {'id': 51, 'name': 'King Fahad Quran Complex', 'author': 'King Fahad Quran Complex', 'language': 'Thai'},
  ];

  Map<int, double> _downloadProgress = {};

  @override
  Widget build(BuildContext context) {
    final transManager = Provider.of<TranslationManagerProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final primaryColor = settings.getPrimaryColor();

    return Card(
      color: widget.colors.surfaceMuted,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Downloaded Translations', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: widget.colors.textStrong)),
            const SizedBox(height: 8),
            // Legacy built-in translations
            _buildLegacyCheckbox(settings, 'thai_v3', 'Thai (V3)'),
            _buildLegacyCheckbox(settings, 'thai_v2', 'Thai (V2)'),
            _buildLegacyCheckbox(settings, 'english', 'English (MHE)'),
            
            const Divider(),
            Text('Download More', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: widget.colors.textStrong)),
            const SizedBox(height: 8),
            ..._availableTranslations.map((t) {
              final isDownloaded = transManager.downloadedTranslations.any((dt) => dt['id'] == t['id']);
              final progress = _downloadProgress[t['id']];
              
              return ListTile(
                title: Text(t['name'], style: GoogleFonts.inter(color: widget.colors.textStrong, fontSize: 14)),
                subtitle: Text('${t['language']} - ${t['author']}', style: GoogleFonts.inter(color: widget.colors.foreground, fontSize: 12)),
                trailing: isDownloaded 
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteTranslation(t['id'], transManager, settings),
                    )
                  : (progress != null)
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: progress, color: primaryColor, strokeWidth: 2))
                    : IconButton(
                        icon: Icon(Icons.download, color: primaryColor),
                        onPressed: () => _downloadTranslation(t),
                      ),
                leading: isDownloaded ? Checkbox(
                  value: settings.primaryTranslationId == t['id'].toString() || settings.secondaryTranslationId == t['id'].toString(),
                  activeColor: primaryColor,
                  onChanged: (val) async {
                    if (val == true) {
                      await transManager.loadTranslationIntoCache(t['id']);
                      if (settings.secondaryTranslationId == null && settings.primaryTranslationId != t['id'].toString()) {
                        settings.updateTranslationSlot('secondary', t['id'].toString());
                      } else {
                        settings.updateTranslationSlot('secondary', t['id'].toString());
                      }
                    } else {
                      final idStr = t['id'].toString();
                      if (settings.primaryTranslationId == idStr) {
                         if (settings.secondaryTranslationId != null) {
                           settings.updateTranslationSlot('primary', settings.secondaryTranslationId);
                           settings.updateTranslationSlot('secondary', null);
                         } else {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one translation must be active.')));
                         }
                      } else {
                         settings.updateTranslationSlot('secondary', null);
                      }
                    }
                  }
                ) : null,
              );
            }).toList()
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyCheckbox(SettingsProvider settings, String id, String label) {
    final isPrimary = settings.primaryTranslationId == id;
    final isSecondary = settings.secondaryTranslationId == id;
    final isChecked = isPrimary || isSecondary;

    return CheckboxListTile(
      title: Text(label, style: GoogleFonts.inter(color: widget.colors.textStrong)),
      subtitle: isPrimary ? Text('Primary', style: GoogleFonts.inter(color: widget.colors.primary, fontSize: 12)) : null,
      value: isChecked,
      activeColor: settings.getPrimaryColor(),
      onChanged: (val) {
        if (val == true) {
          if (settings.secondaryTranslationId == null && settings.primaryTranslationId != id) {
            settings.updateTranslationSlot('secondary', id);
          } else {
            settings.updateTranslationSlot('secondary', id);
          }
        } else {
          if (isPrimary) {
             if (settings.secondaryTranslationId != null) {
               settings.updateTranslationSlot('primary', settings.secondaryTranslationId);
               settings.updateTranslationSlot('secondary', null);
             } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one translation must be active.')));
             }
          } else {
             settings.updateTranslationSlot('secondary', null);
          }
        }
      },
    );
  }

  Future<void> _downloadTranslation(Map<String, dynamic> t) async {
    final id = t['id'] as int;
    setState(() {
      _downloadProgress[id] = 0.0;
    });

    final success = await TranslationDownloader.downloadTranslation(
      id, t['name'], t['author'], t['language'],
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _downloadProgress[id] = p;
          });
        }
      }
    );

    if (mounted) {
      setState(() {
        _downloadProgress.remove(id);
      });
      if (success) {
        Provider.of<TranslationManagerProvider>(context, listen: false).refreshDownloadedList();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t['name']} downloaded!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download ${t['name']}')));
      }
    }
  }
  
  Future<void> _deleteTranslation(int id, TranslationManagerProvider transManager, SettingsProvider settings) async {
    final idStr = id.toString();
    if (settings.primaryTranslationId == idStr || settings.secondaryTranslationId == idStr) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete active translation.')));
      return;
    }
    await transManager.deleteTranslation(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translation deleted.')));
  }
}
