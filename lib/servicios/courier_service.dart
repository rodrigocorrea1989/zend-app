import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';
import 'rider_service.dart' show RegistroException;

enum CourierStatus { pending, approved, rejected }

/// Datos del rider logueado (unión de `profiles` y `couriers`).
class CourierInfo {
  const CourierInfo({
    required this.name,
    required this.vehicle,
    required this.status,
    required this.isOnline,
    required this.rating,
  });

  final String name;
  final VehicleType vehicle;
  final CourierStatus status;
  final bool isOnline;
  final double rating;

  CourierInfo copyWith({bool? isOnline}) => CourierInfo(
    name: name,
    vehicle: vehicle,
    status: status,
    isOnline: isOnline ?? this.isOnline,
    rating: rating,
  );
}

class CourierService {
  CourierService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<CourierInfo> load() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw RegistroException('Tu sesión expiró. Volvé a ingresar.');
    }

    try {
      final profile =
      await _client.from('profiles').select('name').eq('id', uid).single();
      final courier = await _client
          .from('couriers')
          .select('vehicle_type, status, is_online, rating')
          .eq('id', uid)
          .single();

      return CourierInfo(
        name: (profile['name'] as String?) ?? '',
        vehicle: VehicleType.values.firstWhere(
              (v) => v.name == courier['vehicle_type'],
          orElse: () => VehicleType.bicycle,
        ),
        status: CourierStatus.values.firstWhere(
              (s) => s.name == courier['status'],
          orElse: () => CourierStatus.pending,
        ),
        isOnline: courier['is_online'] as bool? ?? false,
        rating: (courier['rating'] as num?)?.toDouble() ?? 0,
      );
    } on PostgrestException {
      throw RegistroException('No pudimos cargar tus datos. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }
  }

  /// Cambia el estado online y devuelve el valor que quedó guardado en la
  /// base. Usa la función `set_courier_online` (ver supabase/online_toggle.sql).
  Future<bool> setOnline(bool online) async {
    try {
      final res =
      await _client.rpc('set_courier_online', params: {'p_online': online});
      return res as bool;
    } on PostgrestException catch (e) {
      debugPrint('set_courier_online falló: ${e.code} ${e.message}');
      if (e.code == 'PGRST202') {
        throw RegistroException(
          'Falta crear la función set_courier_online en Supabase '
              '(ejecutá supabase/online_toggle.sql).',
        );
      }
      if (e.message.contains('not_allowed')) {
        throw RegistroException('No encontramos tu perfil de rider.');
      }
      throw RegistroException('No pudimos cambiar tu estado. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }
  }
}