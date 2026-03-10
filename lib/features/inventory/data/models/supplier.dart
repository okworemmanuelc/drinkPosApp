// Supplier model
// TODO: define Supplier class
import 'crate_group.dart';

class Supplier {
  final String id;
  String name;
  CrateGroup crateGroup;
  bool trackInventory;
  String contactDetails;
  double amountPaid;
  double supplierWallet;

  Supplier({
    required this.id,
    required this.name,
    required this.crateGroup,
    this.trackInventory = true,
    this.contactDetails = '',
    this.amountPaid = 0.0,
    this.supplierWallet = 0.0,
  });
}
