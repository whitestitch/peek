import 'package:shared_preferences/shared_preferences.dart';

class TermsService {
  static const String _termsAcceptedKey = 'terms_accepted';
  static const String _termsAcceptedDateKey = 'terms_accepted_date';

  /// Check if user has accepted terms
  static Future<bool> hasAcceptedTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_termsAcceptedKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get the date when terms were accepted
  static Future<DateTime?> getTermsAcceptedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_termsAcceptedDateKey);
      if (dateString != null) {
        return DateTime.parse(dateString);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Accept terms (called from the UI)
  // static Future<bool> acceptTerms() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setBool(_termsAcceptedKey, true);
  //     await prefs.setString(
  //         _termsAcceptedDateKey, DateTime.now().toIso8601String());
  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  static Future<void> acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termsAccepted', true); // Make sure this has 'await'
  }

  /// Reset terms acceptance (for testing or re-onboarding)
  static Future<void> resetTermsAcceptance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_termsAcceptedKey);
      await prefs.remove(_termsAcceptedDateKey);
    } catch (e) {
      // Handle error silently or log
    }
  }
}
