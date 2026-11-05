import 'package:flutter/material.dart';

/// Pie de página con el crédito del desarrollador.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Text(
          'Desarrollado por Rodrigo Correa',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: Colors.black45,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}