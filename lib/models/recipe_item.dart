class RecipeItem {
  String product;
  double costPerUnit;
  double required;

  RecipeItem({
    required this.product,
    required this.costPerUnit,
    required this.required,
  });

  double get totalCost => costPerUnit * required;
}
