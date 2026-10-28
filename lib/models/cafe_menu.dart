class CafeMenu {
  final int id;
  final String name;
  final String category;
  final double price;
  final bool isAvailable;

  const CafeMenu({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.isAvailable,
  });

  factory CafeMenu.fromJson(Map<String, dynamic> json) {
    return CafeMenu(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Lainnya',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      isAvailable: json['is_available'].toString() == '1' ||
          json['is_available'].toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'is_available': isAvailable,
    };
  }
}