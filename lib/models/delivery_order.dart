enum OrderStatus {
  pending('pending', 'Buscando rider'),
  accepted('accepted', 'Rider asignado'),
  pickedUp('picked_up', 'En camino'),
  delivered('delivered', 'Entregado'),
  cancelled('cancelled', 'Cancelado');

  const OrderStatus(this.db, this.label);
  final String db;
  final String label;

  static OrderStatus fromDb(String? v) => values.firstWhere(
        (s) => s.db == v,
        orElse: () => OrderStatus.pending,
      );
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.description,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.createdAt,
    this.notes,
    this.deliveredAt,
    this.contactName,
    this.contactAvatarPath,
  });

  final String id;
  final String description;
  final String pickupAddress;
  final String dropoffAddress;
  final String? notes;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  /// Nombre y foto de la otra parte: el rider (si lo ve el customer) o el
  /// customer (si lo ve el rider). Solo existen cuando el pedido fue aceptado.
  final String? contactName;
  final String? contactAvatarPath;

  DeliveryOrder withContact(String? name, String? avatarPath) => DeliveryOrder(
        id: id,
        description: description,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        status: status,
        createdAt: createdAt,
        notes: notes,
        deliveredAt: deliveredAt,
        contactName: (name == null || name.trim().isEmpty) ? null : name.trim(),
        contactAvatarPath:
            (avatarPath == null || avatarPath.isEmpty) ? null : avatarPath,
      );

  factory DeliveryOrder.fromMap(Map<String, dynamic> m) => DeliveryOrder(
        id: m['id'] as String,
        description: m['description'] as String,
        pickupAddress: m['pickup_address'] as String,
        dropoffAddress: m['dropoff_address'] as String,
        notes: m['notes'] as String?,
        status: OrderStatus.fromDb(m['status'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        deliveredAt: m['delivered_at'] == null
            ? null
            : DateTime.parse(m['delivered_at'] as String).toLocal(),
      );
}
