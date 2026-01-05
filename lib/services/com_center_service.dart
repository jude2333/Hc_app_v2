// FILE: lib/services/com_center_service.dart

import 'package:anderson_crm_flutter/database/com_center.dart';

class ComCenterService {
  final ComCenter _comCenter;

  ComCenterService(this._comCenter);

  Future<String> sendMessage(Map<String, dynamic> message) async {
    return _comCenter.sendMsg(message);
  }

  Future<void> refreshToken() async {
    return _comCenter.refreshToken();
  }
}
