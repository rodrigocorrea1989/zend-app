import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../initio/my_home_page.dart';
import '../models/delivery_order.dart';
import '../models/user_role.dart';
import '../servicios/auth_service.dart';
import '../servicios/courier_service.dart';
import '../servicios/order_service.dart';
import '../servicios/rider_service.dart' show RegistroException;
import '../widgets/order_cards.dart';

/// Menú principal del rider.
class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final _courierService = CourierService();
  final _authService = AuthService();
  final _orders = OrderService();

  CourierInfo? _info;
  List<DeliveryOrder> _available = [];
  DeliveryOrder? _active;
  String? _acceptingId;
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _toggling = false;
  bool _advancing = false;
  String? _error;

  Color get _color => UserRole.rider.color;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  // Cuando cambia un pedido (nuevo, tomado por otro, etc.), recargamos.
  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('rider-orders')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      callback: (_) {
        if (mounted) _loadOrders();
      },
    )
        .subscribe();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _courierService.load();
      if (!mounted) return;
      setState(() => _info = info);
      await _loadOrders();
    } on RegistroException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (_info != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrders() async {
    try {
      final active = await _orders.activeOrder();
      final online = _info?.isOnline ?? false;
      final available = (online && active == null)
          ? await _orders.availableOrders()
          : <DeliveryOrder>[];
      if (!mounted) return;
      setState(() {
        _active = active;
        _available = available;
      });
    } on RegistroException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _accept(DeliveryOrder order) async {
    if (_acceptingId != null) return;
    setState(() => _acceptingId = order.id);
    try {
      await _orders.accept(order.id);
    } on RegistroException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) setState(() => _acceptingId = null);
    await _loadOrders();
  }

  Future<void> _advance(DeliveryOrder order) async {
    if (_advancing) return;
    final delivering = order.status == OrderStatus.pickedUp;

    if (delivering) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Confirmás la entrega?'),
          content: const Text(
              'Le vamos a avisar al cliente que su pedido fue entregado.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Todavía no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí, entregado'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _advancing = true);
    try {
      await _orders.advance(order.id);
      if (mounted && delivering) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Entrega confirmada! Buen trabajo.')),
        );
      }
    } on RegistroException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) setState(() => _advancing = false);
    await _loadOrders();
  }

  Future<void> _toggleOnline(bool value) async {
    final info = _info;
    if (info == null || _toggling) return;

    setState(() => _toggling = true);
    try {
      // Lo que se muestra es lo que quedó guardado en la base.
      final saved = await _courierService.setOnline(value);
      if (!mounted) return;
      setState(() => _info = info.copyWith(isOnline: saved));
      await _loadOrders();
    } on RegistroException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _logout() async {
    // Si estaba online, lo dejamos offline antes de salir.
    final info = _info;
    if (info != null && info.isOnline) {
      try {
        await _courierService.setOnline(false);
      } catch (_) {}
    }
    await _authService.logout();
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
            Icon(Icons.pedal_bike, color: _color),
            const SizedBox(width: 8),
            Text(
              'Zend Rider',
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
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _info == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final info = _info;
    if (info == null) {
      return _ErrorView(message: _error ?? 'Error', onRetry: _load);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              _Header(info: info, color: _color),
              const SizedBox(height: 24),
              if (info.status != CourierStatus.approved) ...[
                _StatusBanner(status: info.status),
                const SizedBox(height: 16),
              ],
              _OnlineCard(
                isOnline: info.isOnline,
                enabled: !_toggling,
                color: _color,
                onChanged: _toggleOnline,
              ),
              const SizedBox(height: 16),
              if (_active != null)
                ActiveOrderCard(
                  order: _active!,
                  color: _color,
                  advancing: _advancing,
                  onAdvance: () => _advance(_active!),
                )
              else if (info.isOnline && _available.isNotEmpty)
                for (final o in _available) ...[
                  AvailableOrderCard(
                    order: o,
                    color: _color,
                    busy: _acceptingId == o.id,
                    onAccept: _acceptingId == null ? () => _accept(o) : null,
                  ),
                  const SizedBox(height: 12),
                ]
              else
                _EmptyOrders(isOnline: info.isOnline, color: _color),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info, required this.color});

  final CourierInfo info;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final firstName = info.name.trim().split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstName.isEmpty ? '¡Hola!' : '¡Hola, $firstName!',
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.electric_bike_outlined,
              label: info.vehicle.label,
              color: color,
            ),
            _InfoChip(
              icon: Icons.star_rounded,
              label: info.rating > 0
                  ? info.rating.toStringAsFixed(1)
                  : 'Sin calificaciones',
              color: color,
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({
    required this.isOnline,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });

  final bool isOnline;
  final bool enabled;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = isOnline ? Colors.white : Colors.black87;
    final sub = isOnline ? Colors.white70 : Colors.black54;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOnline ? color : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? color : Colors.black).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xFF7CFFB2) : Colors.grey,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Estás online' : 'Estás offline',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline
                      ? 'Podés recibir pedidos cercanos.'
                      : 'Conectate para empezar a recibir pedidos.',
                  style: text.bodyMedium?.copyWith(color: sub, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isOnline,
            onChanged: enabled ? onChanged : null,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white.withValues(alpha: 0.35);
              }
              return Colors.grey.shade400;
            }),
            trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    final rejected = status == CourierStatus.rejected;
    final color = rejected ? const Color(0xFFB3261E) : const Color(0xFF9A6700);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? Icons.block : Icons.hourglass_top_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rejected
                  ? 'Tu solicitud fue rechazada. Contactanos si creés que es un error.'
                  : 'Tu cuenta está en revisión. Ya podés conectarte; te avisaremos cuando aprobemos tu vehículo.',
              style: TextStyle(color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.isOnline, required this.color});

  final bool isOnline;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            isOnline ? Icons.radar : Icons.inbox_outlined,
            size: 44,
            color: color.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            isOnline ? 'Buscando pedidos…' : 'Sin pedidos por ahora',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isOnline
                ? 'Cuando haya un pedido cerca, te va a aparecer acá.'
                : 'Ponete online para que te lleguen pedidos.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: Colors.black38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}