import 'package:onlymens/core/globals.dart';
import 'package:onlymens/core/user_model.dart';

class OBDataService {
  Future<void> onboardUser(CurrentUser user) async {
    // Save user data to Firestore
    await cloudDB.collection('users').doc(user.uid).set(user.toMap());
  }
}
