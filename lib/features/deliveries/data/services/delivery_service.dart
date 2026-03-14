import 'package:flutter/foundation.dart';
import '../../../../core/database/repositories/delivery_repository.dart';
import 'package:drink_pos_app/features/deliveries/data/models/delivery.dart';
import '../../../../shared/services/notification_service.dart';

class DeliveryService extends ValueNotifier<List<Delivery>> {
  DeliveryService() : super([]);

  Future<void> init() async {
    value = await deliveryRepository.getAll();
  }

  void addDelivery(Delivery delivery) {
    value = [...value, delivery];
    deliveryRepository.insert(delivery);
    notificationService.createNotification(
      'new_delivery',
      'New delivery received from ${delivery.supplierName}',
      linkedRecordId: delivery.id,
    );
  }

  List<Delivery> getAll() {
    final list = List<Delivery>.from(value);
    list.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    return list;
  }
}

final deliveryService = DeliveryService();
