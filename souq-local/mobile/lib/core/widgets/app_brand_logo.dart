import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// MarGem brand logo — uses asset when available, with a painted fallback.
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
    return Semantics(
      label: 'MarGem logo',
      child: switch (variant) {
        AppBrandLogoVariant.full => Image.asset(
            _logoAsset,
            width: width ?? 260,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _FallbackLogo(showTagline: true, iconSize: iconSize + 28),
          ),
        AppBrandLogoVariant.icon => Image.asset(
            _logoAsset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _FallbackLogo(showTagline: false, iconSize: iconSize),
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(height: iconSize * 0.55),
      },
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
  const _Wordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: height, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        children: const [
          TextSpan(text: 'Mar', style: TextStyle(color: AppColors.charcoal)),
          TextSpan(text: 'Gem', style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.showTagline, required this.iconSize});

  final bool showTagline;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(iconSize, iconSize),
          painter: _MarGemGemPainter(),
        ),
        if (showTagline) ...[
          SizedBox(height: iconSize * 0.28),
          _Wordmark(height: iconSize * 0.34),
          SizedBox(height: iconSize * 0.12),
          Text(
            'DISCOVER MOROCCO\'S HIDDEN GEMS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: iconSize * 0.11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

class _MarGemGemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final gem = Path()
      ..moveTo(cx, h * 0.06)
      ..lineTo(w * 0.92, h * 0.38)
      ..lineTo(cx, h * 0.94)
      ..lineTo(w * 0.08, h * 0.38)
      ..close();

    canvas.drawPath(gem, Paint()..color = AppColors.charcoal);
    canvas.drawPath(gem, Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04);

    final mPath = Path()
      ..moveTo(cx - w * 0.18, h * 0.42)
      ..lineTo(cx - w * 0.1, h * 0.24)
      ..lineTo(cx, h * 0.36)
      ..lineTo(cx + w * 0.1, h * 0.24)
      ..lineTo(cx + w * 0.18, h * 0.42);
    canvas.drawPath(mPath, Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round);

    canvas.drawCircle(Offset(cx, h * 0.12), w * 0.05, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
