import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';
import 'rider_service.dart' show RegistroException;

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Inicia sesión con email y contraseña y devuelve el rol guardado en
  /// `profiles` (customer, rider o store).
  ///
  /// Lanza [RegistroException] con un mensaje listo para mostrar.
  Future<UserRole> login({
    required String email,
    required String password,
  }) async {
    final AuthResponse res;
    try {
      res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw RegistroException(_mensajeAuth(e));
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }

    final user = res.user;
    if (user == null) {
      throw RegistroException('No pudimos iniciar sesión. Intentá de nuevo.');
    }

    // Verificación en el código: si el email no está confirmado, no se entra.
    if (user.emailConfirmedAt == null) {
      await _client.auth.signOut();
      throw RegistroException(
        'Primero confirmá tu email (revisá tu bandeja de entrada).',
      );
    }

    try {
      // La política RLS deja leer solo la fila propia.
      final row = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        await _client.auth.signOut();
        throw RegistroException('Tu cuenta no tiene un perfil asociado.');
      }

      final roleName = row['role'] as String;
      return UserRole.values.firstWhere(
            (r) => r.name == roleName,
        orElse: () => UserRole.customer,
      );
    } on RegistroException {
      rethrow;
    } on PostgrestException {
      await _client.auth.signOut();
      throw RegistroException('No pudimos cargar tu perfil. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }
  }

  Future<void> logout() => _client.auth.signOut();


  /// Rol de la sesión guardada, o `null` si no hay una sesión válida.
  ///
  /// Lanza [RegistroException] si hay sesión pero no pudimos leer el perfil
  /// (por ejemplo, sin internet). En ese caso NO se cierra la sesión.
  Future<UserRole?> currentRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    if (user.emailConfirmedAt == null) {
      await _client.auth.signOut();
      return null;
    }

    try {
      final row = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        await _client.auth.signOut();
        return null;
      }

      final roleName = row['role'] as String;
      return UserRole.values.firstWhere(
            (r) => r.name == roleName,
        orElse: () => UserRole.customer,
      );
    } on PostgrestException catch (e) {
      // Token inválido o vencido: la sesión ya no sirve.
      if (e.code == 'PGRST301' || e.message.contains('JWT')) {
        await _client.auth.signOut();
        return null;
      }
      throw RegistroException('No pudimos cargar tu perfil. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }
  }


  String _mensajeAuth(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Email o contraseña incorrectos.';
    // case 'email_not_confirmed':
    //   return 'Primero confirmá tu email (revisá tu bandeja de entrada).';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Demasiados intentos. Esperá unos minutos.';
      default:
        return 'No pudimos iniciar sesión. Intentá de nuevo.';
    }
  }
}

