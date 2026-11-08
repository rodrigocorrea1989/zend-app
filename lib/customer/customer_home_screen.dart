import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../initio/my_home_page.dart';
import '../models/delivery_order.dart';
import '../models/user_role.dart';
import '../servicios/auth_service.dart';
import '../servicios/customer_service.dart';
import '../servicios/order_service.dart';
import '../servicios/rider_service.dart' show RegistroException;
import '../servicios/avatar_service.dart';
import '../widgets/order_cards.dart';
import '../widgets/profile_photo.dart';
import 'new_order_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _orders = OrderService();
  final _customers = CustomerService();
  final _auth = AuthService();
  final _avatars = AvatarService();

  List<DeliveryOrder> _list = [];
  String _name = '';
  String? _avatarPath;
  bool _uploadingPhoto = false;
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  Color get _color => UserRole.customer.color;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    _syncAvatar();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  // Cuando cambia un pedido (por ejemplo, un rider lo acepta), recargamos.
  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('customer-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    try {
      final list = await _orders.myOrders();
      final name = _name.isEmpty ? await _customers.name() : _name;
      if (!mounted) return;
      final before = {for (final o in _list) o.id: o.status};
      final justDelivered = list.any((o) =>
          before[o.id] != null &&
          before[o.id] != OrderStatus.delivered &&
          o.status == OrderStatus.delivered);
      setState(() {
        _list = list;
        _name = name;
        _error = null;
      });
      if (justDelivered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Tu pedido fue entregado!')),
        );
      }
    } on RegistroException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Sube la foto elegida en el registro (si quedó pendiente) y lee la actual.
  Future<void> _syncAvatar() async {
    var path = await _avatars.uploadPendingIfAny();
    path ??= await _avatars.currentPath();
    if (!mounted) return;
    setState(() => _avatarPath = path);
  }

  Future<void> _changePhoto(Uint8List bytes) async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      final path = await _avatars.upload(bytes);
      if (!mounted) return;
      setState(() => _avatarPath = path);
    } on RegistroException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _newOrder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewOrderScreen()),
    );
    if (created == true && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Pedido enviado! Buscando un rider…')),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyHomePage(title: 'Zend')),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, color: _color),
            const SizedBox(width: 8),
            Text(
              'Zend',
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Pedir mandado'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 44, color: Colors.black38),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final text = Theme.of(context).textTheme;
    final firstName = _name.trim().split(' ').first;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
            children: [
              Row(
                children: [
                  ProfilePhotoPicker(
                    name: _name,
                    color: _color,
                    path: _avatarPath,
                    busy: _uploadingPhoto,
                    radius: 34,
                    onPicked: _changePhoto,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName.isEmpty ? '¡Hola!' : '¡Hola, $firstName!',
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Tus pedidos', style: text.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_list.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 44, color: _color.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      Text('Todavía no pediste nada',
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Tocá “Pedir mandado” para que un rider lo lleve.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                )
              else
                for (final o in _list) ...[
                  _OrderTile(order: o, color: _color),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.color});

  final DeliveryOrder order;
  final Color color;

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.pending:
        return const Color(0xFF9A6700);
      case OrderStatus.accepted:
      case OrderStatus.pickedUp:
        return const Color(0xFF2F5D9E);
      case OrderStatus.delivered:
        return const Color(0xFF0F5C4D);
      case OrderStatus.cancelled:
        return const Color(0xFFB3261E);
    }
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sc = _statusColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                      color: sc, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OrderRoute(
            pickup: order.pickupAddress,
            dropoff: order.dropoffAddress,
            color: color,
          ),
          if (order.contactName != null) ...[
            const SizedBox(height: 12),
            OrderContactLine(
              label: 'Tu rider',
              name: order.contactName!,
              avatarPath: order.contactAvatarPath,
              color: color,
            ),
          ],
          const SizedBox(height: 10),
          Text(_fmt(order.createdAt),
              style: text.bodySmall?.copyWith(color: Colors.black45)),
        ],
      ),
    );
  }
}
