/// Shared utility for calculating stock value.
/// Formula: Stock Value = sellingPrice * quantity
int calculateStockValue({required double quantity, required int sellingPrice}) {
  return (quantity * sellingPrice).toInt();
}
