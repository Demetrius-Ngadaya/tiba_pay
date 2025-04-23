class Item {
  final String itemId;
  final String itemName;
  final String itemCategory;
  final double itemPrice;
  final String itemSponsor;
  final bool isActive;
  final DateTime createdAt;

  Item({
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.itemPrice,
    required this.itemSponsor,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemCategory': itemCategory,
      'itemPrice': itemPrice,
      'itemSponsor': itemSponsor,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      itemId: map['itemId'],
      itemName: map['itemName'],
      itemCategory: map['itemCategory'],
      itemPrice: map['itemPrice'],
      itemSponsor: map['itemSponsor'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}