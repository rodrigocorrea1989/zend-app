import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import 'profile_photo.dart';

/// Origen → destino en vertical.
class OrderRoute extends StatelessWidget {
  const OrderRoute({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.color,
  });

  final String pickup;
  final String dropoff;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Stop(
            icon: Icons.trip_origin,
            label: 'Retirar en',
            address: pickup,
            color: color),
        Padding(
          padding: const EdgeInsets.only(left: 9),
          child: Container(
            width: 2,
            height: 14,
            color: color.withValues(alpha: 0.3),
          ),
        ),
        _Stop(
            icon: Icons.place,
            label: 'Entregar en',
            address: dropoff,
            color: color),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String address;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: text.bodySmall?.copyWith(color: Colors.black54)),
              Text(address,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Línea con el nombre de la otra parte del pedido.
class OrderContactLine extends StatelessWidget {
  const OrderContactLine({
    super.key,
    required this.label,
    required this.name,
    required this.color,
    this.avatarPath,
  });

  final String label;
  final String name;
  final Color color;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          UserAvatar(name: name, path: avatarPath, color: color, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: text.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  TextSpan(
                    text: name,
                    style: text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pedido disponible para el rider, con botón de aceptar.
class AvailableOrderCard extends StatelessWidget {
  const AvailableOrderCard({
    super.key,
    required this.order,
    required this.color,
    required this.busy,
    required this.onAccept,
  });

  final DeliveryOrder order;
  final Color color;
  final bool busy;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(order.description,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          OrderRoute(
              pickup: order.pickupAddress,
              dropoff: order.dropoffAddress,
              color: color),
          if (order.notes != null) ...[
            const SizedBox(height: 12),
            Text('Nota: ${order.notes}',
                style: text.bodySmall?.copyWith(color: Colors.black54)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Aceptar pedido'),
          ),
        ],
      ),
    );
  }
}

/// Pedido que el rider ya aceptó.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.color,
    this.onAdvance,
    this.advancing = false,
  });

  final DeliveryOrder order;
  final Color color;

  /// Avanza el pedido (retirado / entregado). Si es null, no se muestra el botón.
  final VoidCallback? onAdvance;
  final bool advancing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: color),
              const SizedBox(width: 8),
              Text('Pedido en curso',
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              const Spacer(),
              Text(order.status.label,
                  style: text.bodySmall?.copyWith(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.description,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (order.contactName != null) ...[
            const SizedBox(height: 12),
            OrderContactLine(
              label: 'Pedido de',
              name: order.contactName!,
              avatarPath: order.contactAvatarPath,
              color: color,
            ),
          ],
          const SizedBox(height: 14),
          OrderRoute(
              pickup: order.pickupAddress,
              dropoff: order.dropoffAddress,
              color: color),
          if (order.notes != null) ...[
            const SizedBox(height: 12),
            Text('Nota: ${order.notes}',
                style: text.bodySmall?.copyWith(color: Colors.black54)),
          ],
          if (onAdvance != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: advancing ? null : onAdvance,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: advancing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(order.status == OrderStatus.pickedUp
                      ? Icons.check_circle_outline
                      : Icons.inventory_2_outlined),
              label: Text(order.status == OrderStatus.pickedUp
                  ? 'Confirmar entrega'
                  : 'Ya retiré el pedido'),
            ),
          ],
        ],
      ),
    );
  }
}
