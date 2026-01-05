import 'package:flutter/foundation.dart';

class SmsTemplate {
  static String homeCollectionCancellation(String rescheduleUrl) {
    String message =
        "We have cancelled your home collection request based on your request from Anderson Diagnostics & Labs. Kindly reschedule your appointment request by click here $rescheduleUrl";

    message = Uri.encodeComponent(message);
    message = "&templateid=1207162787348873286&sms=$message";

    return message;
  }

  static String homeCollectionTechChange(
      String technicianName, String mobileNumber, String url) {
    String message =
        "Technician has been changed due to operational reason, for collecting your samples from Anderson Diagnostics & Labs. "
        "$technicianName will visit your home for sample collection. Technician mobile number is "
        "$mobileNumber. Please click here to view about technician details $url";

    message = Uri.encodeComponent(message);
    message = "&templateid=1207162787337166061&sms=$message";

    debugPrint(message);
    return message;
  }

  static String billDetails(String billNo, String testName, String date) {
    String message =
        "Received with thanks $billNo towards inv $testName dt $date - Anderson Diagnostics & Labs. contact 9176677700 for any mismatch";

    message = Uri.encodeComponent(message);
    message = "&templateid=1207162787374145483&sms=$message";

    return message;
  }

  static String workOrderPatientOtp(String otp, String url) {
    String message =
        "$otp is your OTP for ordering the tests. Please visit $url for the test allocated to you and share this OTP with the technician - Anderson Diagnostic Labs ";

    message = Uri.encodeComponent(message);
    message = "&templateid=1207165760370268539&sms=$message";

    return message;
  }

  static String loginOtp(String otp) {
    String message = "$otp is your OTP to login - Anderson Diagnostics & Labs";

    message = Uri.encodeComponent(message);
    message = "&templateid=1207162445556927603&sms=$message";

    return message;
  }

  static String sampleCollection(String patientName, String technicianName,
      String datetime, String mobile, String technicianUrl) {
    String message =
        "Thank you $patientName for choosing Anderson diagnostics. "
        "$technicianName will reach you by $datetime. Technician mobile number is "
        "$mobile. Please click here to view about technician details $technicianUrl";

    message = Uri.encodeComponent(message);
    message = "&templateid=1207162787314553406&sms=$message";

    return message;
  }

  static String workorderConfirmation(String datetime) {
    String message =
        "Sir/Mam, home collection appointment is confirmed for $datetime. "
        "Technician details will be sent once assigned. For enq 9176677601 - Anderson diagnostics.";

    message = Uri.encodeComponent(message);
    message = "&templateid=1107173919243058226&sms=$message";

    return message;
  }
}
