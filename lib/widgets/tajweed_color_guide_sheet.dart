import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../shared/localization.dart';
import '../theme/app_theme.dart';

class TajweedRuleItem {
  final String id;
  final String name;
  final String nameAr;
  final String duration;
  final String description;
  final String letters;
  final String exampleAr;
  final String exampleTranslit;
  final Color color;
  final Color colorBg;
  final Color colorBorder;

  const TajweedRuleItem({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.duration,
    required this.description,
    required this.letters,
    required this.exampleAr,
    required this.exampleTranslit,
    required this.color,
    required this.colorBg,
    required this.colorBorder,
  });
}

class TajweedColorGuideSheet extends StatelessWidget {
  final AppThemeColors colors;

  const TajweedColorGuideSheet({super.key, required this.colors});

  static List<TajweedRuleItem> getRules(String lang, bool isDark) {
    switch (lang) {
      case 'en':
        return [
          TajweedRuleItem(
            id: 'ghunnah',
            name: 'Ghunnah',
            nameAr: 'غُنَّة',
            duration: 'Hold for 2 Harakat',
            description:
                'Nasalized sound held for 2 counts on Noon Mushaddadah (نّ) or Meem Mushaddadah (مّ).',
            letters: 'نّ, مّ',
            exampleAr: 'إِنَّ ٱللَّهَ • ثُمَّ',
            exampleTranslit: 'Inna Allāh • Thumma',
            color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
            colorBg: isDark ? const Color(0x28EA580C) : const Color(0x14EA580C),
            colorBorder: isDark ? const Color(0x50EA580C) : const Color(0x33EA580C),
          ),
          TajweedRuleItem(
            id: 'idgham',
            name: 'Idgham',
            nameAr: 'إِدْغَام',
            duration: 'Hold for 2 Harakat (Except for ل, ر)',
            description:
                'Merging of Noon Sakinah or Tanween into the following letter.',
            letters: 'ي, ر, م, ل, و, ن (Yarmaloon)',
            exampleAr: 'مَن يَقُولُ • غَفُورٌ رَّحِيمٌ',
            exampleTranslit: 'May-yaqūlu • Ghafūrur-Rahīm',
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            colorBg: isDark ? const Color(0x280284C7) : const Color(0x140284C7),
            colorBorder: isDark ? const Color(0x500284C7) : const Color(0x330284C7),
          ),
          TajweedRuleItem(
            id: 'ikhfa',
            name: 'Ikhfa',
            nameAr: 'الإِخْفَاء',
            duration: 'Hold for 2 Harakat',
            description:
                'Concealing the sound of Noon Sakinah or Tanween midway between Izhar and Idgham with nasalization.',
            letters: 'ت, ث, ج, د, ذ, ز, س, ش, ص, ض, ط, ظ, ف, ق, ك (15 letters)',
            exampleAr: 'مِن قَبْلُ • أَنفُسَكُمْ',
            exampleTranslit: 'Min qablu • Anfusakum',
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            colorBg: isDark ? const Color(0x28059669) : const Color(0x14059669),
            colorBorder: isDark ? const Color(0x50059669) : const Color(0x33059669),
          ),
          TajweedRuleItem(
            id: 'iqlab',
            name: 'Iqlab',
            nameAr: 'الإِقْلَاب',
            duration: 'Hold for 2 Harakat',
            description:
                'Converting the sound of Noon Sakinah or Tanween into a Meem (م) when followed by the letter Ba (ب).',
            letters: 'ب (indicated by a small Meem ۘ)',
            exampleAr: 'مِن بَعْدِ • عَلِيمٌۢ بِذَاتِ',
            exampleTranslit: 'Mim-ba‘di • ‘Alīmum-bi-dhāti',
            color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
            colorBg: isDark ? const Color(0x289333EA) : const Color(0x149333EA),
            colorBorder: isDark ? const Color(0x509333EA) : const Color(0x339333EA),
          ),
          TajweedRuleItem(
            id: 'qalqalah',
            name: 'Qalqalah',
            nameAr: 'القَلْقَلَة',
            duration: 'Echoing sound',
            description:
                'Echoing or bouncing sound produced when a Qalqalah letter has a Sukoon or is stopped upon.',
            letters: 'ق, ط, ب, ج, د (Qutb Jad)',
            exampleAr: 'يَجْعَلُونَ • ٱلْفَلَقِ',
            exampleTranslit: 'Yaj‘alūna • Al-Falaq',
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            colorBg: isDark ? const Color(0x284F46E5) : const Color(0x144F46E5),
            colorBorder: isDark ? const Color(0x504F46E5) : const Color(0x334F46E5),
          ),
          TajweedRuleItem(
            id: 'madd',
            name: 'Madd Wajib / Madd Lazim (Madd 4-6 Harakat)',
            nameAr: 'مَدّ وَاجِب / لَازِم',
            duration: 'Prolong for 4 to 6 Harakat',
            description:
                'Extended elongation when a Madd letter carries a wavy mark (~) followed by Hamzah or Sukoon.',
            letters: 'آ, يٓ, وٓ (wavy mark ~)',
            exampleAr: 'جَآءَ • ٱلصَّآخَّةُ',
            exampleTranslit: 'Jāaa'a • As-Sāaakh-khah',
            color: isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
            colorBg: isDark ? const Color(0x28E11D48) : const Color(0x14E11D48),
            colorBorder: isDark ? const Color(0x50E11D48) : const Color(0x33E11D48),
          ),
        ];
      case 'ms':
        return [
          TajweedRuleItem(
            id: 'ghunnah',
            name: 'Ghunnah (Dengung)',
            nameAr: 'غُنَّة',
            duration: 'Dengung 2 Harakat',
            description:
                'Mendengungkan suara ke pangkal hidung selama 2 harakat apabila bertemu Nun Syaddah (نّ) atau Mim Syaddah (مّ).',
            letters: 'نّ, مّ',
            exampleAr: 'إِنَّ ٱللَّهَ • ثُمَّ',
            exampleTranslit: 'Inna Allāh • Thumma',
            color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
            colorBg: isDark ? const Color(0x28EA580C) : const Color(0x14EA580C),
            colorBorder: isDark ? const Color(0x50EA580C) : const Color(0x33EA580C),
          ),
          TajweedRuleItem(
            id: 'idgham',
            name: 'Idgham (Memasukkan / Menggabungkan)',
            nameAr: 'إِدْغَام',
            duration: 'Dengung 2 Harakat (Kecuali ل, ر)',
            description:
                'Memasukkan bunyi Nun Mati (Sakinah) atau Tanwin ke dalam huruf selepasnya.',
            letters: 'ي, ر, م, ل, و, ن (Yarmalun)',
            exampleAr: 'مَن يَقُولُ • غَفُورٌ رَّحِيمٌ',
            exampleTranslit: 'May-yaqūlu • Ghafūrur-Rahīm',
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            colorBg: isDark ? const Color(0x280284C7) : const Color(0x140284C7),
            colorBorder: isDark ? const Color(0x500284C7) : const Color(0x330284C7),
          ),
          TajweedRuleItem(
            id: 'ikhfa',
            name: 'Ikhfa' (Menyembunyikan)',
            nameAr: 'الإِخْفَاء',
            duration: 'Dengung 2 Harakat',
            description:
                'Membaca Nun Mati (Sakinah) atau Tanwin secara samar di antara Izhar dan Idgham berserta dengung.',
            letters: 'ت, ث, ج, د, ذ, ز, س, ش, ص, ض, ط, ظ, ف, ق, ك (15 huruf)',
            exampleAr: 'مِن قَبْلُ • أَنفُسَكُمْ',
            exampleTranslit: 'Min qablu • Anfusakum',
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            colorBg: isDark ? const Color(0x28059669) : const Color(0x14059669),
            colorBorder: isDark ? const Color(0x50059669) : const Color(0x33059669),
          ),
          TajweedRuleItem(
            id: 'iqlab',
            name: 'Iqlab (Menukar Bunyi)',
            nameAr: 'الإِقْلَاب',
            duration: 'Dengung 2 Harakat',
            description:
                'Menukarkan bunyi Nun Mati (Sakinah) atau Tanwin kepada bunyi Mim (م) apabila bertemu huruf Ba (ب).',
            letters: 'ب (ditandai dengan Mim kecil ۘ)',
            exampleAr: 'مِن بَعْدِ • عَلِيمٌۢ بِذَاتِ',
            exampleTranslit: 'Mim-ba‘di • ‘Alīmum-bi-dhāti',
            color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
            colorBg: isDark ? const Color(0x289333EA) : const Color(0x149333EA),
            colorBorder: isDark ? const Color(0x509333EA) : const Color(0x339333EA),
          ),
          TajweedRuleItem(
            id: 'qalqalah',
            name: 'Qalqalah (Lantunan)',
            nameAr: 'القَلْقَلَة',
            duration: 'Lantunan suara',
            description:
                'Melantunkan bunyi huruf apabila huruf Qalqalah bertanda Sukun (mati) atau diwaqafkan (berhenti).',
            letters: 'ق, ط, ب, ج, د (Qutbu Jaddin)',
            exampleAr: 'يَجْعَلُونَ • ٱلْفَلَقِ',
            exampleTranslit: 'Yaj‘alūn • Al-Falaq',
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            colorBg: isDark ? const Color(0x284F46E5) : const Color(0x144F46E5),
            colorBorder: isDark ? const Color(0x504F46E5) : const Color(0x334F46E5),
          ),
          TajweedRuleItem(
            id: 'madd',
            name: 'Mad Wajib / Mad Lazim (Mad 4-6 Harakat)',
            nameAr: 'مَدّ وَاجِب / لَازِم',
            duration: 'Panjang 4 hingga 6 Harakat',
            description:
                'Memanjangkan bacaan apabila huruf Mad mempunyai tanda ombak (~) dan diikuti oleh Hamzah atau Sukun.',
            letters: 'آ, يٓ, وٓ (simbol ombak ~)',
            exampleAr: 'جَآءَ • ٱلصَّآخَّةُ',
            exampleTranslit: 'Jāaa'a • As-Sāaakh-khah',
            color: isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
            colorBg: isDark ? const Color(0x28E11D48) : const Color(0x14E11D48),
            colorBorder: isDark ? const Color(0x50E11D48) : const Color(0x33E11D48),
          ),
        ];
      case 'th':
      default:
        return [
          TajweedRuleItem(
            id: 'ghunnah',
            name: 'ฆุนนะฮ์ (Ghunnah)',
            nameAr: 'غُنَّة',
            duration: 'หน่วงเสียง 2 ฮารอกาต',
            description:
                'หน่วงเสียงขึ้นจมูก 2 ฮารอกาต เมื่อพบนูนชัดดะฮ์ (نّ) หรือมีมชัดดะฮ์ (مّ)',
            letters: 'نّ, مّ',
            exampleAr: 'إِنَّ ٱللَّهَ • ثُمَّ',
            exampleTranslit: 'อินนัลลอฮ์ • ษุมมะ',
            color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
            colorBg: isDark ? const Color(0x28EA580C) : const Color(0x14EA580C),
            colorBorder: isDark ? const Color(0x50EA580C) : const Color(0x33EA580C),
          ),
          TajweedRuleItem(
            id: 'idgham',
            name: 'อิดฆอม (Idgham)',
            nameAr: 'إِدْغَام',
            duration: 'หน่วงเสียง 2 ฮารอกาต (ยกเว้น ل, ر)',
            description:
                'การอ่านกล้ำเสียงนูนสุกูน (นูนตาย) หรือตันวีนเข้าสู่อักษรตัวถัดไป',
            letters: 'ي, ر, م, ل, و, ن (ยัรมะลูน)',
            exampleAr: 'مَن يَقُولُ • غَفُورٌ رَّحِيمٌ',
            exampleTranslit: 'มัยยะกูลุ • เฆาะฟูรุรเราะฮีม',
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            colorBg: isDark ? const Color(0x280284C7) : const Color(0x140284C7),
            colorBorder: isDark ? const Color(0x500284C7) : const Color(0x330284C7),
          ),
          TajweedRuleItem(
            id: 'ikhfa',
            name: 'อิคฟาอ์ (Ikhfa)',
            nameAr: 'الإِخْفَاء',
            duration: 'หน่วงเสียง 2 ฮารอกาต',
            description:
                'การอ่านซ่อนเสียงนูนสุกูน (นูนตาย) หรือตันวีน ให้อยู่กึ่งกลางระหว่างอิซฮารและอิดฆอม พร้อมหน่วงเสียงขึ้นจมูก',
            letters: 'ت, ث, ج, د, ذ, ز, س, ش, ص, ض, ط, ظ, ف, ق, ك (15 อักษร)',
            exampleAr: 'مِن قَبْلُ • أَنفُسَكُمْ',
            exampleTranslit: 'มิงก็อบลิ • อันฟุสะกุม',
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            colorBg: isDark ? const Color(0x28059669) : const Color(0x14059669),
            colorBorder: isDark ? const Color(0x50059669) : const Color(0x33059669),
          ),
          TajweedRuleItem(
            id: 'iqlab',
            name: 'อิกลาบ (Iqlab)',
            nameAr: 'الإِقْلَاب',
            duration: 'หน่วงเสียง 2 ฮารอกาต',
            description:
                'การแปลงเสียงนูนสุกูน (นูนตาย) หรือตันวีน ให้เป็นเสียงอักษรมีม (م) เมื่อพบกับอักษรบาอ์ (ب)',
            letters: 'ب (พร้อมเครื่องหมาย มีม ตัวเล็ก ۘ)',
            exampleAr: 'مِن بَعْدِ • عَلِيمٌۢ بِذَاتِ',
            exampleTranslit: 'มิมบะอ์ดิ • อะลีมัมบิซาติ',
            color: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
            colorBg: isDark ? const Color(0x289333EA) : const Color(0x149333EA),
            colorBorder: isDark ? const Color(0x509333EA) : const Color(0x339333EA),
          ),
          TajweedRuleItem(
            id: 'qalqalah',
            name: 'ก็อลเกาะละฮ์ (Qalqalah)',
            nameAr: 'القَلْقَلَة',
            duration: 'สะท้อนเสียง',
            description:
                'การสะท้อนหรือกระดอนเสียง เมื่ออักษรก็อลเกาะละฮ์มีเครื่องหมายสุกูน (เครื่องหมายตาย) หรือหยุดอ่านที่อักษรนั้น',
            letters: 'ق, ط, ب, ج, د (กุฏบุญัดด์)',
            exampleAr: 'يَجْعَلُونَ • ٱلْفَلَقِ',
            exampleTranslit: 'ยัจญ์อะลูน • อัลฟะลัก',
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            colorBg: isDark ? const Color(0x284F46E5) : const Color(0x144F46E5),
            colorBorder: isDark ? const Color(0x504F46E5) : const Color(0x334F46E5),
          ),
          TajweedRuleItem(
            id: 'madd',
            name: 'มัดด์วาญิบ / มัดด์ลาซิม (Madd 4-6 Harakat)',
            nameAr: 'مَدّ وَاجِب / لَازِم',
            duration: 'ยาว 4 - 6 ฮารอกาต',
            description:
                'การลากเสียงยาวเป็นพิเศษ เมื่อมีเครื่องหมายคลื่น (~) บนอักษรมัดด์ตามด้วยฮัมซะฮ์หรือสุกูน',
            letters: 'آ, يٓ, وٓ (เครื่องหมายคลื่น ~)',
            exampleAr: 'جَآءَ • ٱلصَّآخَّةُ',
            exampleTranslit: 'ญาาาอะ • อัศศอคเคาะฮ์',
            color: isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
            colorBg: isDark ? const Color(0x28E11D48) : const Color(0x14E11D48),
            colorBorder: isDark ? const Color(0x50E11D48) : const Color(0x33E11D48),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String lang = 'th';
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      lang = settings.languageCode;
    } catch (_) {}

    final rules = getRules(lang, isDark);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('tajweed_guide_title'),
                      style: GoogleFonts.notoSansThai(
                        color: colors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('tajweed_guide_desc'),
                      style: GoogleFonts.notoSansThai(
                        color: colors.foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = rules[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: r.colorBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: r.colorBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: r.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    r.name,
                                    style: GoogleFonts.notoSansThai(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: r.color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${r.nameAr})',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontFamily: 'Tajweed',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.borderSoft),
                            ),
                            child: Text(
                              r.duration,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.textStrong,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.description,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          color: colors.textStrong,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: colors.borderSoft.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: context.tr('tajweed_applicable_letters'),
                                    style: GoogleFonts.notoSansThai(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: colors.foreground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: r.letters,
                                    style: GoogleFonts.notoSansThai(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: colors.textStrong,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: context.tr('tajweed_examples'),
                                    style: GoogleFonts.notoSansThai(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: colors.foreground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: r.exampleAr,
                                    style: const TextStyle(
                                      fontFamily: 'Tajweed',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' (${r.exampleTranslit})',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 11,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('tajweed_got_it'),
              style: GoogleFonts.notoSansThai(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
