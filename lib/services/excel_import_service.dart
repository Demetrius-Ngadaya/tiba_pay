import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/user.dart';

class ExcelImportService {
  static final Uuid _uuid = Uuid();

  static Future<List<Item>?> importItemsFromExcel(User currentUser) async {
    try {
      // Pick the Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) return null;

      // Get the file path
      String? filePath = result.files.single.path;
      if (filePath == null) return null;

      // Read the Excel file
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      // Get the first sheet
      var sheet = excel.tables[excel.tables.keys.first]!;

      List<Item> items = [];
      
      // Skip header row (row 0) and process each row
      for (var row in sheet.rows.skip(1)) {
        try {
          if (row.length >= 5) { // Ensure minimum columns exist
            Item item = Item(
              itemId: _uuid.v4(), // Generate unique ID
              itemName: row[0]?.value?.toString() ?? '',
              itemCategory: row[1]?.value?.toString() ?? 'OTHER',
              itemPrice: double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0,
              itemSponsor: row[3]?.value?.toString() ?? 'CASH SELF REFERRAL',
              isActive: (row[4]?.value?.toString() ?? 'true').toLowerCase() == 'true',
              createdAt: DateTime.now(),
              createdBy: currentUser.fullName,
            );
            items.add(item);
          }
        } catch (e) {
          print('Error parsing row: $e');
        }
      }

      return items;
    } catch (e) {
      print('Error importing Excel: $e');
      return null;
    }
  }
}