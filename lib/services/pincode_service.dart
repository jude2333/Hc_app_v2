import '../database/pincode_db.dart';

class PincodeService {
  final PincodeDB _pincodeDB;

  PincodeService(this._pincodeDB);

  Future<List<Map<String, dynamic>>> searchPincodes(String query) async {
    return await _pincodeDB.fetchData(query);
  }

  Future<List<Map<String, dynamic>>> getInitialPincodes() async {
    return await _pincodeDB.fetchInitialData();
  }
}
