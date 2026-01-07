import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'db_handler.dart';
import 'couch_db.dart';

class PincodeDB {
  final DBHandler _dbHandler;
  final CouchDBClient _couchDB;

  PincodeDB(this._dbHandler, this._couchDB);

  Future<List<Map<String, dynamic>>> fetchData(String searchStr) async {
    debugPrint('PincodeDB.fetchData() > $searchStr');

    String? name = _dbHandler.resolveName('pin_codes');
    if (name == null) {
      debugPrint('Could not resolve pin_codes database name');
      return _emptyResult();
    }

    Dio remoteDb = await _couchDB.getDB(name);

    List<Map<String, dynamic>> items = [];
    String str = searchStr.trim();

    try {
      int? numericSearch = int.tryParse(str);

      Map<String, dynamic> queryParams = {
        'include_docs': true,
      };

      if (numericSearch != null && str.isNotEmpty) {
        queryParams['startkey'] = jsonEncode('pin:code_$numericSearch');
        queryParams['endkey'] = jsonEncode('pin:code_$numericSearch\ufff0');
      } else if (str.isNotEmpty) {
        queryParams['startkey'] = jsonEncode('pin:code_');
        queryParams['endkey'] = jsonEncode('pin:code_\ufff0');
      } else {
        queryParams['startkey'] = jsonEncode('pin:code_');
        queryParams['endkey'] = jsonEncode('pin:code_\ufff0');
        queryParams['limit'] = 10;
      }

      Response response = await remoteDb.get(
        '/_all_docs',
        queryParameters: queryParams,
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null) {
            Map<String, dynamic> item = Map<String, dynamic>.from(row['doc']);

            if (_matchesCriteria(item, str)) {
              items.add(item);
            }

            if (items.length > 9) {
              break;
            }
          }
        }
      }

      if (items.isEmpty) {
        return _emptyResult();
      }

      debugPrint('Found ${items.length} pincode results');
      return items;
    } catch (e) {
      debugPrint('Error fetching pincode data: $e');
      return _emptyResult();
    }
  }

  Future<List<Map<String, dynamic>>> fetchInitialData() async {
    debugPrint('PincodeDB.fetchInitialData()');
    return fetchData('');
  }

  bool _matchesCriteria(Map<String, dynamic> item, String searchStr) {
    if (searchStr.isEmpty) return true;

    String lowerSearch = searchStr.toLowerCase();

    String pincode = (item['pincode'] ?? '').toString().toLowerCase();
    if (pincode.contains(lowerSearch)) return true;

    String area = (item['area'] ?? '').toString().toLowerCase();
    if (area.contains(lowerSearch)) return true;

    String district = (item['district'] ?? '').toString().toLowerCase();
    if (district.contains(lowerSearch)) return true;

    String city = (item['city'] ?? '').toString().toLowerCase();
    if (city.contains(lowerSearch)) return true;

    return false;
  }

  List<Map<String, dynamic>> _emptyResult() {
    return [
      {
        'pincode': 'No Pincode Found.',
        'area': 'NA',
        'district': 'NA',
        'city': 'NA',
      }
    ];
  }
}
