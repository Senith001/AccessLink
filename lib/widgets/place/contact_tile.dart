import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/place_detail.dart';

class ContactTile extends StatelessWidget {
  final ContactInfo contact;

  const ContactTile({
    super.key,
    required this.contact,
  });

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _ensureHttpsScheme(String website) {
    if (website.startsWith('http://') || website.startsWith('https://')) {
      return website;
    }
    return 'https://$website';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (!contact.hasAny) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.contact_phone,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Contact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Contact details not available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.contact_phone,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Contact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Contact rows
          Column(
            children: [
              if (contact.phone.isNotEmpty)
                _ContactRow(
                  icon: Icons.call,
                  label: contact.phone,
                  semanticsLabel: 'Call ${contact.phone}',
                  onTap: () => _launchUrl(context, 'tel:${contact.phone}'),
                ),
              if (contact.email.isNotEmpty)
                _ContactRow(
                  icon: Icons.email,
                  label: contact.email,
                  semanticsLabel: 'Email ${contact.email}',
                  onTap: () => _launchUrl(context, 'mailto:${contact.email}'),
                ),
              if (contact.website.isNotEmpty)
                _ContactRow(
                  icon: Icons.language,
                  label: contact.website,
                  semanticsLabel: 'Visit website ${contact.website}',
                  onTap: () => _launchUrl(context, _ensureHttpsScheme(contact.website)),
                  isLast: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool isLast;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: isLast ? null : Border(
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}