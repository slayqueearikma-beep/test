import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// User-friendly error state for failed API loads (no dev instructions in production).
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  factory AsyncErrorView.fromError(Object error, {VoidCallback? onRetry}) {
    final text = error is ApiException
        ? error.message
        : (AppConfig.isProduction
            ? 'Something went wrong. Please try again.'
            : error.toString());
    return AsyncErrorView(message: text, onRetry: onRetry);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
