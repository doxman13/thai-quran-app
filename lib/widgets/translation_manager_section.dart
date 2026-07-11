import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/translation_manager_provider.dart';
import '../services/translation_downloader.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';

class TranslationManagerSection extends StatefulWidget {
  final AppThemeColors colors;
  const TranslationManagerSection({super.key, required this.colors});

  @override
  State<TranslationManagerSection> createState() =>
      _TranslationManagerSectionState();
}

class _TranslationManagerSectionState extends State<TranslationManagerSection> {
  static const _builtInThaiV3 = _TranslationOption(
    id: 'thai_v3',
    apiId: null,
    name: 'Arab Alumni Association',
    nameTh: 'สมาคมศิษย์เก่าอาหรับ (ฉบับปรับปรุงภาษา)',
    author: 'Arab Alumni Association',
    language: 'thai',
  );

  static const List<_TranslationOption> _availableTranslations = [
    _TranslationOption(
      id: '51',
      apiId: 51,
      name: 'Thai Translation (King Fahad Quran Complex)',
      nameTh: 'ศูนย์กษัตริย์ฟะฮัดเพื่อการพิมพ์อัลกุรอาน',
      author: 'King Fahad Quran Complex',
      language: 'thai',
    ),
    _TranslationOption(
      id: '230',
      apiId: 230,
      name: 'Society of Institutes and Universities',
      nameTh: 'Society of Institutes and Universities (Original)',
      author: 'Society of Institutes and Universities',
      language: 'thai',
    ),
    _TranslationOption(
      id: '85',
      apiId: 85,
      name: 'M.A.S. Abdel Haleem',
      author: 'Abdul Haleem',
      language: 'english',
    ),
    _TranslationOption(
      id: '20',
      apiId: 20,
      name: 'Saheeh International',
      author: 'Saheeh International',
      language: 'english',
    ),
    _TranslationOption(
      id: '84',
      apiId: 84,
      name: 'T. Usmani',
      author: 'Mufti Taqi Usmani',
      language: 'english',
    ),
    _TranslationOption(
      id: '39',
      apiId: 39,
      name: 'Abdullah Muhammad Basmeih',
      author: 'Abdullah Muhammad Basmeih',
      language: 'malay',
    ),
  ];

  final Map<int, double> _downloadProgress = {};

  @override
  Widget build(BuildContext context) {
    final transManager = context.watch<TranslationManagerProvider>();
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final downloadedOptions = _downloadedOptions(transManager);

    return Card(
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(colorScheme, context.tr('active_translations')),
            const SizedBox(height: 8),
            _buildTranslationRow(
              option: _builtInThaiV3,
              settings: settings,
              colorScheme: colorScheme,
            ),
            ...downloadedOptions.map(
              (option) => _buildTranslationRow(
                option: option,
                settings: settings,
                colorScheme: colorScheme,
                onDelete: () => _deleteTranslation(
                  int.parse(option.id),
                  transManager,
                  settings,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            _sectionTitle(colorScheme, context.tr('download_more')),
            const SizedBox(height: 8),
            ..._groupedAvailableTranslations().entries.expand((entry) {
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    _languageLabel(entry.key, settings.languageCode),
                    style: GoogleFonts.notoSansThai(
                      color: colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ...entry.value.map((option) {
                  final isDownloaded = downloadedOptions.any(
                    (item) => item.id == option.id,
                  );
                  final progress = option.apiId == null
                      ? null
                      : _downloadProgress[option.apiId];

                  return _buildTranslationRow(
                    option: option,
                    settings: settings,
                    colorScheme: colorScheme,
                    isDownloaded: isDownloaded,
                    progress: progress,
                    onDownload: option.apiId == null || isDownloaded
                        ? null
                        : () => _downloadTranslation(option),
                    onDelete: isDownloaded
                        ? () => _deleteTranslation(
                            option.apiId!,
                            transManager,
                            settings,
                          )
                        : null,
                  );
                }),
              ];
            }),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ColorScheme colorScheme, String title) {
    return Text(
      title,
      style: GoogleFonts.notoSansThai(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTranslationRow({
    required _TranslationOption option,
    required SettingsProvider settings,
    required ColorScheme colorScheme,
    bool isDownloaded = true,
    double? progress,
    VoidCallback? onDownload,
    VoidCallback? onDelete,
  }) {
    final isPrimary = settings.primaryTranslationId == option.id;
    final isSecondary = settings.secondaryTranslationId == option.id;
    final isChecked = isPrimary || isSecondary;
    final canSelect = option.apiId == null || isDownloaded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.displayName(settings.languageCode),
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPrimary
                      ? context.tr('primary')
                      : isSecondary
                      ? context.tr('secondary')
                      : option.author,
                  style: GoogleFonts.notoSansThai(
                    color: isPrimary || isSecondary
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: isPrimary || isSecondary
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (progress != null) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: progress,
                color: colorScheme.primary,
                strokeWidth: 2,
              ),
            ),
          ] else if (canSelect) ...[
            Checkbox(
              value: isChecked,
              activeColor: colorScheme.primary,
              onChanged: (value) => _toggleTranslation(
                settings: settings,
                id: option.id,
                isPrimary: isPrimary,
                value: value,
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                color: colorScheme.error,
                onPressed: onDelete,
              ),
          ] else if (onDownload != null) ...[
            IconButton(
              tooltip: context.tr('download_more'),
              icon: const Icon(Icons.download_rounded),
              color: colorScheme.primary,
              onPressed: onDownload,
            ),
          ],
        ],
      ),
    );
  }

  void _toggleTranslation({
    required SettingsProvider settings,
    required String id,
    required bool isPrimary,
    required bool? value,
  }) {
    if (value == true) {
      settings.updateTranslationSlot('secondary', id);
      return;
    }

    if (isPrimary) {
      if (settings.secondaryTranslationId != null) {
        settings.updateTranslationSlot(
          'primary',
          settings.secondaryTranslationId,
        );
        settings.updateTranslationSlot('secondary', null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('at_least_one_active'))),
        );
      }
      return;
    }

    settings.updateTranslationSlot('secondary', null);
  }

  Future<void> _downloadTranslation(_TranslationOption option) async {
    final id = option.apiId;
    if (id == null) return;

    setState(() {
      _downloadProgress[id] = 0;
    });

    final success = await TranslationDownloader.downloadTranslation(
      id,
      option.name,
      option.author,
      option.language,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[id] = progress;
          });
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _downloadProgress.remove(id);
    });

    if (success) {
      await context.read<TranslationManagerProvider>().refreshDownloadedList();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${option.displayName(settingsLanguage)} downloaded!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download ${option.name}')),
      );
    }
  }

  String get settingsLanguage {
    return context.read<SettingsProvider>().languageCode;
  }

  Future<void> _deleteTranslation(
    int id,
    TranslationManagerProvider transManager,
    SettingsProvider settings,
  ) async {
    final idStr = id.toString();
    if (settings.primaryTranslationId == idStr ||
        settings.secondaryTranslationId == idStr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete active translation.')),
      );
      return;
    }
    await transManager.deleteTranslation(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Translation deleted.')));
  }

  List<_TranslationOption> _downloadedOptions(
    TranslationManagerProvider transManager,
  ) {
    return transManager.downloadedTranslations.map((item) {
      final id = item['id'].toString();
      final known = _availableTranslations
          .where((option) => option.id == id)
          .firstOrNull;
      if (known != null) return known;

      return _TranslationOption(
        id: id,
        apiId: int.tryParse(id),
        name: item['name']?.toString() ?? 'Downloaded translation',
        author: item['author_name']?.toString() ?? '',
        language: item['language_name']?.toString() ?? '',
      );
    }).toList()..sort(_compareTranslationOptions);
  }

  Map<String, List<_TranslationOption>> _groupedAvailableTranslations() {
    final sorted = [..._availableTranslations]
      ..sort(_compareTranslationOptions);
    final groups = <String, List<_TranslationOption>>{};
    for (final option in sorted) {
      groups.putIfAbsent(option.language, () => []).add(option);
    }
    return groups;
  }

  int _compareTranslationOptions(_TranslationOption a, _TranslationOption b) {
    final languageCompare = _languageSortOrder(
      a.language,
    ).compareTo(_languageSortOrder(b.language));
    if (languageCompare != 0) return languageCompare;
    return a.name.compareTo(b.name);
  }

  int _languageSortOrder(String language) {
    return switch (language.toLowerCase()) {
      'thai' => 0,
      'english' => 1,
      'malay' => 2,
      _ => 99,
    };
  }

  String _languageLabel(String language, String appLanguage) {
    final normalized = language.toLowerCase();
    if (appLanguage == 'th') {
      return switch (normalized) {
        'thai' => 'ภาษาไทย',
        'english' => 'ภาษาอังกฤษ',
        'malay' => 'ภาษามลายู',
        _ => language,
      };
    }
    return switch (normalized) {
      'thai' => 'Thai',
      'english' => 'English',
      'malay' => 'Malay',
      _ => language,
    };
  }
}

class _TranslationOption {
  final String id;
  final int? apiId;
  final String name;
  final String? nameTh;
  final String author;
  final String language;

  const _TranslationOption({
    required this.id,
    required this.apiId,
    required this.name,
    this.nameTh,
    required this.author,
    required this.language,
  });

  String displayName(String appLanguage) {
    if (appLanguage == 'th' && nameTh != null && nameTh!.isNotEmpty) {
      return nameTh!;
    }
    return name;
  }
}
