import 'package:flutter/material.dart';

/// Styling scoped to the authentication pages; the app theme stays unchanged.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final fieldColor = highContrast
        ? colors.surface
        : Color.alphaBlend(
            colors.primary.withValues(alpha: 0.05),
            colors.surface,
          );
    final hintColor = highContrast
        ? colors.onSurface
        : Color.alphaBlend(
            colors.onSurfaceVariant.withValues(alpha: 0.75),
            fieldColor,
          );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: highContrast ? colors.outline : colors.outlineVariant,
      ),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: fieldColor,
          hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w400),
          suffixIconColor: hintColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            minimumSize: const Size(double.infinity, 56),
            elevation: 4,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: body,
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.logoSize});
  final String title;
  final double? logoSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: logoSize ?? (title == 'Login' ? 280 : 220),
          height: logoSize ?? (title == 'Login' ? 280 : 220),
          padding: EdgeInsets.all(logoSize == null ? 28 : logoSize! * 0.1),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/images/logo-login.png',
            fit: BoxFit.contain,
            semanticLabel: 'AccessLink logo',
          ),
        ),
        SizedBox(height: logoSize == null ? 24 : 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: logoSize == null ? 44 : 32,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}