import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../models/user_role.dart';
import '../servicios/order_service.dart';
import '../servicios/rider_service.dart' show RegistroException;
import '../widgets/order_cards.dart';
import '../widgets/profile_photo.dart';

/// Historial de entregas del rider.
class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key});

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  final _orders = OrderService();

  List<DeliveryOrder> _list = [];
  bool _loading = true;
  String? _error;

  Color get _color => UserRole.rider.color;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _orders.deliveredOrders();
      if (!mounted) return;
      setState(() {
        _list = list;
        _error = null;
      });
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

  DateTime _when(DeliveryOrder o) => o.deliveredAt ?? o.createdAt;

  int get _today {
    final n = DateTime.now();
    return _list.where((o) {
      final d = _when(o);
      return d.year == n.year && d.month == n.month && d.day == n.day;
    }).length;
  }

  int get _week {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    return _list.where((o) => _when(o).isAfter(limit)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de entregas'),
        backgroundColor: Colors.transparent,
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
    final total = '${_list.length}${_list.length >= 100 ? '+' : ''}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Row(
                children: [
                  _Stat(label: 'Hoy', value: '$_today', color: _color),
                  const SizedBox(width: 10),
                  _Stat(label: '7 días', value: '$_week', color: _color),
                  const SizedBox(width: 10),
                  _Stat(label: 'Total', value: total, color: _color),
                ],
              ),
              const SizedBox(height: 20),
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
                      Icon(Icons.history,
                          size: 44, color: _color.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      Text('Todavía no hiciste entregas',
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Cuando confirmes tu primera entrega, va a aparecer acá.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                )
              else
                for (final o in _list) ...[
                  _HistoryTile(
                      order: o, color: _color, when: _when(o)),
                  const SizedBox(height: 12),
                ],
              if (_list.length >= 100)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Se muestran tus últimas 100 entregas.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: Colors.black45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: text.bodySmall?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.order,
    required this.color,
    required this.when,
  });

  final DeliveryOrder order;
  final Color color;
  final DateTime when;

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const done = Color(0xFF0F5C4D);

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
              UserAvatar(
                name: order.contactName ?? '',
                path: order.contactAvatarPath,
                color: color,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.contactName ?? 'Cliente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _fmt(when),
                      style: text.bodySmall?.copyWith(color: Colors.black45),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: done.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Entregado',
                  style: TextStyle(
                      color: done, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(order.description,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          OrderRoute(
            pickup: order.pickupAddress,
            dropoff: order.dropoffAddress,
            color: color,
          ),
        ],
      ),
    );
  }
}
