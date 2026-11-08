import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import '../models/user_role.dart';
import '../registro/register_screen.dart';
import '../widgets/app_footer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _openRegister(UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar: const AppFooter(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pedal_bike, size: 44, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: text.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Entregas en bici, e-bike y monopatín.\nSin combustible.',
                    style: text.titleMedium?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 36),
                  for (final role in UserRole.values) ...[
                    _RoleTile(role: role, onTap: () => _openRegister(role)),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _openLogin,
                      child: const Text('Ya tengo cuenta, ingresar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.onTap});

  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: role.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(role.icon, color: role.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.actionLabel,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.description,
                      style: text.bodySmall
                          ?.copyWith(color: Colors.black54, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: role.color),
            ],
          ),
        ),
      ),
    );
  }
}
