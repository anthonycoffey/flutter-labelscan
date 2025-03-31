class ScannedItem {
  final String description;
  final int priceInCents; // Store price as cents

  ScannedItem({required this.description, required this.priceInCents});

  // Helper to get price as formatted USD string
  String get priceFormatted {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return currencyFormat.format(priceInCents / 100.0);
  }
}