import 'package:flutter/material.dart';

enum UserRole { customer, rider, store }

extension UserRoleInfo on UserRole {
  String get actionLabel {
    switch (this) {
      case UserRole.customer:
        return 'Registrarme como usuario';
      case UserRole.rider:
        return 'Registrarme como rider';
      case UserRole.store:
        return 'Registrar mi comercio';
    }
  }

  String get description {
    switch (this) {
      case UserRole.customer:
        return 'Pedí a comercios cercanos y seguí tu entrega en el mapa.';
      case UserRole.rider:
        return 'Repartí en bici, e-bike, monopatín o rollers y ganá por cada entrega.';
      case UserRole.store:
        return 'Vendé tus productos y recibí repartidores sin combustible.';
    }
  }

  String get formTitle {
    switch (this) {
      case UserRole.customer:
        return 'Crear cuenta de usuario';
      case UserRole.rider:
        return 'Crear cuenta de rider';
      case UserRole.store:
        return 'Registrar comercio';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.customer:
        return Icons.shopping_bag_outlined;
      case UserRole.rider:
        return Icons.pedal_bike;
      case UserRole.store:
        return Icons.storefront_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.customer:
        return const Color(0xFF0F5C4D);
      case UserRole.rider:
        return const Color(0xFFC96A12);
      case UserRole.store:
        return const Color(0xFF2F5D9E);
    }
  }
}

/// Solo vehículos sin combustible.
enum VehicleType { bicycle, ebike, scooter, rollers }

extension VehicleTypeInfo on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.bicycle:
        return 'Bicicleta';
      case VehicleType.ebike:
        return 'Bicicleta eléctrica';
      case VehicleType.scooter:
        return 'Monopatín';
      case VehicleType.rollers:
        return 'Rollers';
    }
  }
}
