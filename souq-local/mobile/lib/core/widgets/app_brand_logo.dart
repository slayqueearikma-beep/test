import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// MarGem brand logo — transparent asset with theme-aware fallback.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.variant = AppBrandLogoVariant.full,
    this.width,
    this.height,
    this.iconSize = 40,
  });

  final AppBrandLogoVariant variant;
  final double? width;
  final double? height;
  final double iconSize;

  static const _logoAsset = 'assets/images/margem_logo.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'MarGem logo',
      child: switch (variant) {
        AppBrandLogoVariant.full => _ThemedAssetLogo(
            asset: _logoAsset,
            width: width ?? 260,
            height: height,
            fit: BoxFit.contain,
            isDark: isDark,
            fallback: _FallbackLogo(
              showTagline: true,
              iconSize: iconSize + 28,
              isDark: isDark,
            ),
          ),
        AppBrandLogoVariant.icon => _ThemedAssetLogo(
            asset: _logoAsset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            isDark: isDark,
            fallback: _FallbackLogo(
              showTagline: false,
              iconSize: iconSize,
              isDark: isDark,
            ),
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(height: iconSize * 0.55, isDark: isDark),
      },
    );
  }
}

class _ThemedAssetLogo extends StatelessWidget {
  const _ThemedAssetLogo({
    required this.asset,
    required this.isDark,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final bool isDark;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );

    if (!isDark) return image;

    // Brighten dark gem fills so the transparent logo stays readable on dark surfaces.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.15, 0, 0, 0, 40,
        0, 1.15, 0, 0, 40,
        0, 0, 1.15, 0, 40,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }
}

enum AppBrandLogoVariant { full, icon, wordmark }

/// Backwards-compatible alias used across existing screens.
class AppLogoPlaceholder extends StatelessWidget {
  const AppLogoPlaceholder({
    super.key,
    this.size = 120,
    this.onPurpleBackground = false,
    this.showFullLogo = false,
  });

  final double size;
  final bool onPurpleBackground;
  final bool showFullLogo;

  @override
  Widget build(BuildContext context) {
    if (showFullLogo || size >= 100) {
      return AppBrandLogo(
        variant: AppBrandLogoVariant.full,
        width: size * 2.1,
        iconSize: size * 0.45,
      );
    }

    return AppBrandLogo(
      variant: AppBrandLogoVariant.icon,
      iconSize: size,
    );
  }
}

class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppBrandLogo(variant: AppBrandLogoVariant.icon, iconSize: size);
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height, required this.isDark});

  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final marColor = isDark ? Colors.white : AppColors.charcoal;
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: height, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        children: [
          TextSpan(text: 'Mar', style: TextStyle(color: marColor)),
          const TextSpan(text: 'Gem', style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({
    required this.showTagline,
    required this.iconSize,
    required this.isDark,
  });

  final bool showTagline;
  final double iconSize;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final taglineColor = (isDark ? Colors.white : AppColors.charcoal).withValues(alpha: 0.75);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(iconSize, iconSize),
          painter: _MarGemGemPainter(isDark: isDark),
        ),
        if (showTagline) ...[
          SizedBox(height: iconSize * 0.28),
          _Wordmark(height: iconSize * 0.34, isDark: isDark),
          SizedBox(height: iconSize * 0.12),
          Text(
            'DISCOVER MOROCCO\'S HIDDEN GEMS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: iconSize * 0.11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: taglineColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarGemGemPainter extends CustomPainter {
  _MarGemGemPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final fill = isDark ? const Color(0xFF1A1A1A) : AppColors.charcoal;

    final gem = Path()
      ..moveTo(cx, h * 0.06)
      ..lineTo(w * 0.92, h * 0.38)
      ..lineTo(cx, h * 0.94)
      ..lineTo(w * 0.08, h * 0.38)
      ..close();

    canvas.drawPath(gem, Paint()..color = fill);
    canvas.drawPath(
      gem,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04,
    );

    final mPath = Path()
      ..moveTo(cx - w * 0.18, h * 0.42)
      ..lineTo(cx - w * 0.1, h * 0.24)
      ..lineTo(cx, h * 0.36)
      ..lineTo(cx + w * 0.1, h * 0.24)
      ..lineTo(cx + w * 0.18, h * 0.42);
    canvas.drawPath(
      mPath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(Offset(cx, h * 0.12), w * 0.05, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _MarGemGemPainter oldDelegate) => oldDelegate.isDark != isDark;
}
