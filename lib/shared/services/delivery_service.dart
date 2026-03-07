import 'package:flutter/foundation.dart';
import '../models/delivery.dart';

class DeliveryService extends ValueNotifier<List<Delivery>> {
  DeliveryService() : super([]);

  List<Delivery> getPending() {
    final list = value.where((d) => d.status == 'pending').toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Delivery> getCompleted() {
    final list = value.where((d) => d.status == 'completed').toList();
    list.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );
    return list;
  }

  void addDelivery(Delivery delivery) {
    value = [...value, delivery];
  }

  void markAsCompleted(String deliveryId) {
    final index = value.indexWhere((d) => d.id == deliveryId);
    if (index == -1) return;

    final List<Delivery> newList = List.from(value);
    newList[index] = newList[index].copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
    );
    value = newList;
  }
}

final deliveryService = DeliveryService();
