import 'package:flutter/material.dart';

import '../customer/customer_home_screen.dart';
import '../models/user_role.dart';
import '../rider/rider_home_screen.dart';
import '../servicios/auth_service.dart';
import '../servicios/rider_service.dart' show RegistroException;
import 'my_home_page.dart';

/// Pantalla de arranque: decide a dónde ir según la sesión guardada.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  late Future<Widget> _destino;

  @override
  void initState() {
    super.initState();
    _destino = _resolve();
  }

  Future<Widget> _resolve() async {
    final role = await _auth.currentRole();

    switch (role) {
      case UserRole.rider:
        return const RiderHomeScreen();
      case UserRole.customer:
        return const CustomerHomeScreen();
      case UserRole.store:
        // Todavía no existe ese menú: no dejamos sesión abierta.
        await _auth.logout();
        return const MyHomePage(title: 'Zend');
      case null:
        return const MyHomePage(title: 'Zend');
    }
  }

  void _retry() => setState(() => _destino = _resolve());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destino,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is RegistroException
              ? error.message
              : 'Ocurrió un error inesperado.';
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 44, color: Colors.black38),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
