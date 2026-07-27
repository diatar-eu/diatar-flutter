
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

class OnboardingSheet extends StatelessWidget {
  const OnboardingSheet({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_stories,
                color: cs.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(l10n.appTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _headerCard(
                    icon: Icons.waving_hand,
                    title: l10n.onboardingWelcomeTitle,
                    body: l10n.onboardingWelcomeBody,
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _headerCard(
                    icon: Icons.monitor,
                    title: l10n.onboardingPage2Title,
                    body: l10n.onboardingPage2Body,
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _headerCard(
                    icon: Icons.playlist_add,
                    title: l10n.onboardingPage3Title,
                    body: l10n.onboardingPage3Body,
                    cs: cs,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _headerCard(
                    icon: Icons.auto_awesome,
                    title: l10n.onboardingPage4Title,
                    body: l10n.onboardingPage4Body,
                    cs: cs,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              TextButton(
                onPressed: onComplete,
                child: Text(l10n.onboardingSkip),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(l10n.onboardingGotIt),
                onPressed: onComplete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCard({
    required IconData icon,
    required String title,
    required String body,
    required ColorScheme cs,
    required ThemeData theme,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon,
              color: cs.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
