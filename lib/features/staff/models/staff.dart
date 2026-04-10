class Staff {
  final String id;
  final String name;
  final String role; // CEO, Manager, Storekeeper, Cashier, Rider, Cleaner

  Staff({
    required this.id,
    required this.name,
    required this.role,
  });
}

class StaffService {
  static final List<Staff> _staffList = [];

  List<Staff> getAll() => _staffList;

  List<Staff> getRiders() => _staffList.where((s) => s.role == 'Rider').toList();
}

final staffService = StaffService();
