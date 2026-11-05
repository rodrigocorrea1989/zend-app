import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_order.dart';
import 'rider_service.dart' show RegistroException;

class OrderService {
  OrderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _noNet = 'No pudimos conectarnos. Revisá tu internet.';

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw RegistroException('Tu sesión expiró. Volvé a ingresar.');
    }
    return uid;
  }

  /// Nombre de la otra parte de cada pedido aceptado (ver order_contacts.sql).
  /// Si la función todavía no existe o falla, la app sigue andando sin nombres.
  Future<Map<String, String>> _contacts() async {
    try {
      final rows = await _client.rpc('order_contacts') as List;
      final map = <String, String>{};
      for (final r in rows) {
        final name = (r['contact_name'] as String?) ?? '';
        if (name.trim().isNotEmpty) map[r['order_id'] as String] = name;
      }
      return map;
    } catch (e) {
      debugPrint('order_contacts falló: $e');
      return {};
    }
  }

  // ---------- Customer ----------

  Future<void> create({
    required String description,
    required String pickup,
    required String dropoff,
    String? notes,
  }) async {
    try {
      await _client.from('orders').insert({
        'description': description,
        'pickup_address': pickup,
        'dropoff_address': dropoff,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
      });
    } on PostgrestException catch (e) {
      debugPrint('crear pedido falló: ${e.code} ${e.message}');
      throw RegistroException('No pudimos crear el pedido. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException(_noNet);
    }
  }

  Future<List<DeliveryOrder>> myOrders() async {
    final uid = _uid;
    try {
      final rows = await _client
          .from('orders')
          .select()
          .eq('customer_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      final contacts = await _contacts();
      return rows.map((m) {
        final o = DeliveryOrder.fromMap(m);
        return o.withContact(contacts[o.id]);
      }).toList();
    } on PostgrestException {
      throw RegistroException('No pudimos cargar tus pedidos.');
    } catch (_) {
      throw RegistroException(_noNet);
    }
  }

  // ---------- Rider ----------

  Future<List<DeliveryOrder>> availableOrders() async {
    try {
      final rows = await _client
          .from('orders')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(30);
      return rows.map(DeliveryOrder.fromMap).toList();
    } on PostgrestException {
      throw RegistroException('No pudimos cargar los pedidos.');
    } catch (_) {
      throw RegistroException(_noNet);
    }
  }

  Future<DeliveryOrder?> activeOrder() async {
    final uid = _uid;
    try {
      final row = await _client
          .from('orders')
          .select()
          .eq('courier_id', uid)
          .inFilter('status', ['accepted', 'picked_up'])
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final order = DeliveryOrder.fromMap(row);
      final contacts = await _contacts();
      return order.withContact(contacts[order.id]);
    } on PostgrestException {
      throw RegistroException('No pudimos cargar tu pedido activo.');
    } catch (_) {
      throw RegistroException(_noNet);
    }
  }

  /// Avanza el pedido: aceptado -> retirado -> entregado.
  /// Devuelve el estado que quedó guardado en la base.
  Future<OrderStatus> advance(String orderId) async {
    try {
      final res =
      await _client.rpc('advance_order', params: {'p_order_id': orderId});
      return OrderStatus.fromDb(res as String?);
    } on PostgrestException catch (e) {
      debugPrint('advance_order falló: ${e.code} ${e.message}');
      if (e.code == 'PGRST202') {
        throw RegistroException(
            'Falta crear la función advance_order en Supabase '
                '(ejecutá supabase/order_progress.sql).');
      }
      if (e.message.contains('not_found')) {
        throw RegistroException('No encontramos ese pedido.');
      }
      if (e.message.contains('invalid_state')) {
        throw RegistroException('Ese pedido ya fue entregado o cancelado.');
      }
      throw RegistroException('No pudimos actualizar el pedido. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException(_noNet);
    }
  }

  Future<void> accept(String orderId) async {
    try {
      await _client.rpc('accept_order', params: {'p_order_id': orderId});
    } on PostgrestException catch (e) {
      debugPrint('accept_order falló: ${e.code} ${e.message}');
      if (e.code == 'PGRST202') {
        throw RegistroException(
            'Falta crear la función accept_order en Supabase.');
      }
      if (e.message.contains('not_online')) {
        throw RegistroException('Ponete online para aceptar pedidos.');
      }
      if (e.message.contains('already_active')) {
        throw RegistroException('Ya tenés un pedido en curso.');
      }
      if (e.message.contains('not_available')) {
        throw RegistroException('Ese pedido ya lo tomó otro rider.');
      }
      throw RegistroException('No pudimos aceptar el pedido. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException(_noNet);
    }
  }
}