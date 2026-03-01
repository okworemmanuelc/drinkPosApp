// Supplier model
// TODO: define Supplier class
import 'crate_group.dart';

class Supplier {
  final String id;
  String name;
  CrateGroup crateGroup;
  bool trackInventory;

  Supplier({
    required this.id,
    required this.name,
    required this.crateGroup,
    this.trackInventory = true,
  });
}
