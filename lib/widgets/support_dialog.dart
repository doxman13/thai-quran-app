import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/in_app_purchase_service.dart';
import '../shared/localization.dart';
import '../theme/app_theme.dart';

class SupportDialog extends StatefulWidget {
  const SupportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SupportDialog(),
    );
  }

  @override
  State<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<SupportDialog> {
  final InAppPurchaseService _iapService = InAppPurchaseService();

  @override
  void initState() {
    super.initState();
    _iapService.addListener(_handleIapUpdate);
    if (!kIsWeb) {
      _iapService.loadProducts();
    }
  }

  @override
  void dispose() {
    _iapService.removeListener(_handleIapUpdate);
    super.dispose();
  }

  void _handleIapUpdate() {
    if (!mounted) return;

    if (_iapService.purchaseSuccessMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('support_thank_you'),
            style: GoogleFonts.notoSansThai(),
          ),
          backgroundColor: const Color(0xFF0E5A4A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    if (_iapService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _iapService.errorMessage!,
            style: GoogleFonts.notoSansThai(),
          ),
          backgroundColor: const Color(0xFFA34C43),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _openWebSupport() async {
    final uri = Uri.parse('https://quran-th.com/support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _iconForProduct(String productId) {
    switch (productId) {
      case InAppPurchaseService.tipSmall:
        return Icons.coffee_rounded;
      case InAppPurchaseService.tipMedium:
        return Icons.cloud_done_rounded;
      case InAppPurchaseService.tipLarge:
        return Icons.menu_book_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  String _cleanProductTitle(String rawTitle, String id) {
    String cleaned = rawTitle
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .trim();
    if (cleaned.isNotEmpty) return cleaned;

    switch (id) {
      case InAppPurchaseService.tipSmall:
        return 'เลี้ยงกาแฟทีมพัฒนา';
      case InAppPurchaseService.tipMedium:
        return 'สนับสนุนค่าเซิร์ฟเวอร์';
      case InAppPurchaseService.tipLarge:
        return 'สนับสนุนการพัฒนาอัลกุรอาน';
      default:
        return 'ร่วมสนับสนุน';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIos = !kIsWeb && Platform.isIOS;
    final storeName = isIos ? 'App Store' : 'Google Play';

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: colors.borderSoft),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge & Title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.mushafGoldSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: colors.mushafGoldBorder),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 20,
                      color: colors.mushafGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('support_developer'),
                          style: GoogleFonts.notoSansThai(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textStrong,
                          ),
                        ),
                        Text(
                          'Sadaqah Jariyah • เพื่อการเผยแพร่อัลกุรอาน',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description Text
              Text(
                context.tr('support_desc'),
                style: GoogleFonts.notoSansThai(
                  fontSize: 12.5,
                  height: 1.5,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 16),

              // Product List / State Handler
              if (kIsWeb)
                _buildWebSection(colors)
              else if (_iapService.isLoading && _iapService.products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                )
              else if (!_iapService.isAvailable)
                _buildUnavailableSection(colors, storeName)
              else if (_iapService.products.isEmpty)
                _buildFallbackTiersSection(colors, storeName)
              else
                ..._iapService.products.map(
                  (product) => _buildProductTile(colors, product),
                ),

              const SizedBox(height: 16),
              Divider(height: 1, color: colors.borderSoft),
              const SizedBox(height: 12),

              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'ปิด (Close)',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(AppThemeColors colors, ProductDetails product) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _iapService.isLoading ? null : () => _iapService.buyProduct(product),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(
                _iconForProduct(product.id),
                size: 20,
                color: colors.mushafGold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cleanProductTitle(product.title, product.id),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textStrong,
                      ),
                    ),
                    if (product.description.isNotEmpty)
                      Text(
                        product.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.primaryLightBorder),
                ),
                child: Text(
                  product.price,
                  style: GoogleFonts.notoSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackTiersSection(AppThemeColors colors, String storeName) {
    // Shows the exact items that will be active once Play Store / App Store config is published
    final fallbackItems = [
      {'id': 'thaiquran_tip_small', 'title': 'เลี้ยงกาแฟทีมพัฒนา (Small Tip)', 'price': '~29 ฿'},
      {'id': 'thaiquran_tip_medium', 'title': 'สนับสนุนค่าเซิร์ฟเวอร์ (Medium Tip)', 'price': '~99 ฿'},
      {'id': 'thaiquran_tip_large', 'title': 'สนับสนุนการพัฒนาอัลกุรอาน (Large Tip)', 'price': '~299 ฿'},
    ];

    return Column(
      children: [
        ...fallbackItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: colors.borderSoft),
              ),
              child: Row(
                children: [
                  Icon(
                    _iconForProduct(item['id']!),
                    size: 18,
                    color: colors.mushafGold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['title']!,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textStrong,
                      ),
                    ),
                  ),
                  Text(
                    item['price']!,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _openWebSupport,
          icon: const Icon(Icons.open_in_new_rounded, size: 14),
          label: Text(
            context.tr('support_web_btn'),
            style: GoogleFonts.notoSansThai(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.borderSoft),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebSection(AppThemeColors colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(Icons.volunteer_activism_rounded, color: colors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ท่านสามารถร่วมสนับสนุนผ่านระบบ PromptPay หรือช่องทางบนเว็บไซต์ได้โดยตรง',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _openWebSupport,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(
            context.tr('support_web_btn'),
            style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableSection(AppThemeColors colors, String storeName) {
    return Column(
      children: [
        Text(
          'ระบบชำระเงินของ $storeName ยังไม่พร้อมใช้งานบนอุปกรณ์นี้',
          style: GoogleFonts.notoSansThai(fontSize: 12, color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openWebSupport,
          icon: const Icon(Icons.open_in_new_rounded, size: 14),
          label: Text(
            context.tr('support_web_btn'),
            style: GoogleFonts.notoSansThai(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.borderSoft),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        ),
      ],
    );
  }
}
