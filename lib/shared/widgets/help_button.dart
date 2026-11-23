import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../features/help/domain/help_content.dart';

/// Ikon bantuan di AppBar setiap layar (SRS 2.6, DOCS_SPEC §7.5 butir 3).
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, this.topic = HelpTopic.umum});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Bantuan',
        icon: const Icon(Icons.help_outline),
        onPressed: () => context.push('${Routes.help}?topic=${topic.name}'),
      );
}
