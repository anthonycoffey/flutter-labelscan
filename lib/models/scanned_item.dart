import 'package:intl/intl.dart'; // For currency formatting
class ScannedItem {
  final String description;
  final int priceInCents; // Store price as cents

  ScannedItem({required this.description, required this.priceInCents});

  // Helper to get price as formatted USD string
  String get priceFormatted {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return currencyFormat.format(priceInCents / 100.0);
  }

  // Convert ScannedItem instance to a Map (for Firestore)
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'priceInCents': priceInCents,
    };
  }

  // Create ScannedItem instance from a Map (from Firestore)
  factory ScannedItem.fromJson(Map<String, dynamic> json) {
    return ScannedItem(
      description: json['description'] as String,
      priceInCents: json['priceInCents'] as int,
    );
  }
}
