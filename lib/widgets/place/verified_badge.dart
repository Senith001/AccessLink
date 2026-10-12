import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final bool showFullLabel;
  final DateTime? verifiedDate;
  final String? authorityDescription;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.showFullLabel = false,
    this.verifiedDate,
    this.authorityDescription,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = MediaQuery.highContrastOf(context);

    if (!isVerified) {
      final unverifiedLabel = showFullLabel
          ? 'Not yet verified'
          : 'Not verified';
      return Semantics(
        label: 'Accessibility information is $unverifiedLabel',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isHighContrast
                ? Colors.white
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighContrast ? Colors.black : Colors.grey.shade600,
              width: isHighContrast ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: isHighContrast ? Colors.black : Colors.grey.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                unverifiedLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isHighContrast ? Colors.black : Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final verifiedLabel = showFullLabel
        ? 'Verified accessibility information'
        : 'Verified';

    final badgeColor = isHighContrast
        ? const Color(0xFF003366)
        : colorScheme.primary;

    return Semantics(
      label:
          'Accessibility information is verified${authorityDescription != null ? " by $authorityDescription" : ""}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: isHighContrast ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badgeColor,
            width: isHighContrast ? 2 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 17, color: badgeColor),
                const SizedBox(width: 6),
                Text(
                  verifiedLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (authorityDescription != null || verifiedDate != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (authorityDescription != null) authorityDescription,
                  if (verifiedDate != null) 'on ${_formatDate(verifiedDate!)}',
                ].whereType<String>().join(' '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: badgeColor.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
