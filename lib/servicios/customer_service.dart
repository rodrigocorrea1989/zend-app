import 'package:supabase_flutter/supabase_flutter.dart';

import 'rider_service.dart' show RegistroException;

class CustomerService {
  CustomerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Devuelve `true` si hay que confirmar el email antes de ingresar.
  Future<bool> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final AuthResponse res;
    try {
      res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'customer', 'name': name, 'phone': phone},
      );
    } on AuthException catch (e) {
      throw RegistroException(_mensajeAuth(e));
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }

    final user = res.user;
    if (user == null) {
      throw RegistroException('No pudimos crear la cuenta. Intentá de nuevo.');
    }
    if (user.identities != null && user.identities!.isEmpty) {
      throw RegistroException('Ese email ya está registrado.');
    }
    return res.session == null;
  }

  /// Nombre para el saludo. Si falla, devuelve vacío (no es crítico).
  Future<String> name() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return '';
    try {
      final row =
          await _client.from('profiles').select('name').eq('id', uid).single();
      return (row['name'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  String _mensajeAuth(AuthException e) {
    switch (e.code) {
      case 'user_already_exists':
      case 'email_exists':
        return 'Ese email ya está registrado.';
      case 'weak_password':
        return 'La contraseña es demasiado débil.';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'El email no es válido.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Demasiados intentos. Esperá unos minutos.';
      case 'signup_disabled':
        return 'El registro está deshabilitado en Supabase.';
      default:
        return 'No pudimos crear la cuenta. Intentá de nuevo.';
    }
  }
}
