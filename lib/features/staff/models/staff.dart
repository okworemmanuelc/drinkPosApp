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
  static final List<Staff> _staffList = [
    Staff(id: 's1', name: 'John Okoro', role: 'CEO'),
    Staff(id: 's2', name: 'Alice Smith', role: 'Manager'),
    Staff(id: 's3', name: 'Bob Johnson', role: 'Storekeeper'),
    Staff(id: 's4', name: 'Mary Adams', role: 'Cashier'),
    Staff(id: 's5', name: 'Chukwudi Obi', role: 'Rider'),
    Staff(id: 's6', name: 'Sani Bello', role: 'Rider'),
    Staff(id: 's7', name: 'Grace Ojo', role: 'Cleaner'),
  ];

  List<Staff> getAll() => _staffList;

  List<Staff> getRiders() => _staffList.where((s) => s.role == 'Rider').toList();
}

final staffService = StaffService();
