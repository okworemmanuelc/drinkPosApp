import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/services/cart_service.dart';
import 'package:reebaplus_pos/shared/services/navigation_service.dart';
import 'package:reebaplus_pos/features/customers/data/models/customer.dart';
import 'dart:async';

class PosController extends ChangeNotifier {
  List<ProductDataWithStock> allProducts = [];
  List<CategoryData> categories = [];
  List<ManufacturerData> manufacturers = [];
  int? selectedCategoryId;
  String selectedManufacturerId = 'All';
  CustomerGroup selectedGroup = CustomerGroup.retailer;
  String searchQuery = '';
  bool isSearching = false;
  String? currentWarehouseName;

  bool isLoading = true;
  StreamSubscription? _productsSub;
  Timer? _debounce;

  PosController() {
    _init();
  }

  void _init() {
    _loadCategories();
    _loadManufacturers();
    _subscribeToProducts();
    cartService.activeCustomer.addListener(_onCustomerSelected);
    navigationService.lockedWarehouseId.addListener(_subscribeToProducts);
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _debounce?.cancel();
    cartService.activeCustomer.removeListener(_onCustomerSelected);
    navigationService.lockedWarehouseId.removeListener(_subscribeToProducts);
    super.dispose();
  }

  Future<void> _loadCategories() async {
    categories = await database.select(database.categories).get();
    notifyListeners();
  }

  Future<void> _loadManufacturers() async {
    manufacturers = await database.catalogDao.getAllManufacturers();
    notifyListeners();
  }

  void _subscribeToProducts() {
    _productsSub?.cancel();

    final warehouseId = navigationService.lockedWarehouseId.value;

    final minLoading = Future.delayed(const Duration(seconds: 2));

    if (warehouseId != null) {
      // Fetch warehouse name
      database.warehousesDao.getWarehouse(warehouseId).then((w) {
        currentWarehouseName = w?.name;
        notifyListeners();
      });

      _productsSub = database.inventoryDao
          .watchProductDatasWithStockByWarehouse(warehouseId)
          .listen((data) async {
            await minLoading;
            allProducts = data;
            isLoading = false;
            notifyListeners();
          });
    } else {
      currentWarehouseName = null;
      _productsSub = database.inventoryDao
          .watchProductsByCategory(selectedCategoryId)
          .listen((data) async {
            await minLoading;
            allProducts = data;
            isLoading = false;
            notifyListeners();
          });
    }
  }

  void _onCustomerSelected() {
    final customer = cartService.activeCustomer.value;
    if (customer != null) {
      selectedGroup = customer.customerGroup;
      notifyListeners();
    }
  }

  void selectCategory(int? categoryId) {
    selectedCategoryId = categoryId;
    _subscribeToProducts();
    notifyListeners();
  }

  void selectManufacturer(String manufacturerId) {
    selectedManufacturerId = manufacturerId;
    notifyListeners();
  }

  void selectGroup(CustomerGroup group) {
    selectedGroup = group;
    notifyListeners();
  }

  void toggleSearch() {
    isSearching = !isSearching;
    if (!isSearching) {
      searchQuery = '';
    }
    notifyListeners();
  }

  void updateSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      searchQuery = query;
      notifyListeners();
    });
  }

  List<ProductDataWithStock> get filteredProducts {
    var items = allProducts
        .where(
          (item) =>
              item.totalStock > 0 &&
              item.product.isAvailable &&
              !item.product.isDeleted,
        )
        .where((item) {
          if (selectedManufacturerId == 'All') return true;
          return item.product.manufacturerId?.toString() ==
              selectedManufacturerId;
        })
        .where((item) {
          if (selectedCategoryId == null) return true;
          return item.product.categoryId == selectedCategoryId;
        })
        .toList();

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items
          .where(
            (item) =>
                item.product.name.toLowerCase().contains(q) ||
                (item.product.subtitle?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return items;
  }
}
