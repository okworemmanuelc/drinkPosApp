import 'package:flutter/foundation.dart';
import 'package:drink_pos_app/features/deliveries/data/models/delivery.dart';

class DeliveryService extends ValueNotifier<List<Delivery>> {
  DeliveryService() : super(_initialDeliveries);

  static final List<Delivery> _initialDeliveries = [];

  void addDelivery(Delivery delivery) {
    value = [...value, delivery];
  }

  List<Delivery> getAll() {
    final list = List<Delivery>.from(value);
    list.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    return list;
  }
}

final deliveryService = DeliveryService();
