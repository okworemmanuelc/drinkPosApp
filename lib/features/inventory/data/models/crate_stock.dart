// CrateStock model
// TODO: define CrateStock class
import 'crate_group.dart';

class CrateStock {
  CrateGroup group;
  double available;

  CrateStock({required this.group, this.available = 0});
}
