import 'package:flutter/material.dart';

/// Caps content width on large screens and centers it.
///
/// On a desktop window the text column, word tiles and markdown tables would
/// otherwise stretch across the whole 1900px width — unreadable line lengths
/// and absurdly wide table cells. Phones are narrower than [max], so this is a
/// no-op there.
class PageWidth extends StatelessWidget {
  final Widget child;
  final double max;
  const PageWidth({super.key, required this.child, this.max = 860});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: max),
          child: child,
        ),
      );
}
