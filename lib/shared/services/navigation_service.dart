import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  final ValueNotifier<String?> selectedWarehouseId = ValueNotifier<String?>(null);

  void setIndex(int index) {
    currentIndex.value = index;
  }
}

final navigationService = NavigationService();
