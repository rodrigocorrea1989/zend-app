import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';

/// Error con un mensaje listo para mostrarle al usuario.
class RegistroException implements Exception {
  RegistroException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RiderService {
  RiderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Crea la cuenta del rider.
  ///
  /// Los datos viajan como metadata del usuario y un trigger en la base
  /// (ver supabase/schema.sql) crea las filas en `profiles` y `couriers`.
  /// El courier queda en estado `pending` hasta que alguien revise su vehículo.
  ///
  /// Devuelve `true` si Supabase exige confirmar el email antes de ingresar.
  Future<bool> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required VehicleType vehicle,
  }) async {
    final AuthResponse res;
    try {
      res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'rider',
          'name': name,
          'phone': phone,
          'vehicle_type': vehicle.name,
        },
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

    // Si el email ya existe, Supabase no da error (por seguridad) y devuelve
    // un usuario sin identidades.
    if (user.identities != null && user.identities!.isEmpty) {
      throw RegistroException('Ese email ya está registrado.');
    }

    // Sin sesión = falta confirmar el email.
    return res.session == null;
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
