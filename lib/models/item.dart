import 'package:intl/intl.dart';

class Item {
  final String itemId;
  final String itemName;
  final String itemCategory;
  final double itemPrice;
  final String itemSponsor;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  Item({
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.itemPrice,
    required this.itemSponsor,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      itemId: map['itemId'],
      itemName: map['itemName'],
      itemCategory: map['itemCategory'],
      itemPrice: map['itemPrice'],
      itemSponsor: map['itemSponsor'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemCategory': itemCategory,
      'itemPrice': itemPrice,
      'itemSponsor': itemSponsor,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  String get formattedCreatedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  }
}