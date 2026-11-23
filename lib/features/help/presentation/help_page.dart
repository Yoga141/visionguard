import 'package:flutter/material.dart';

import '../domain/help_content.dart';

/// Bantuan & FAQ dalam aplikasi (SRS 2.6, DOCS_SPEC §7.5). [topic] = bagian
/// yang langsung terbuka, sesuai layar asal ikon bantuan.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key, this.topic = HelpTopic.umum});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = helpSections();
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan & FAQ')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Panduan singkat & pertanyaan umum', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final s in sections)
                  Card(
                    child: ExpansionTile(
                      key: PageStorageKey(s.topic),
                      initiallyExpanded: s.topic == topic,
                      title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in s.entries) ...[
                          const SizedBox(height: 8),
                          Text(e.question, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(e.answer),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
