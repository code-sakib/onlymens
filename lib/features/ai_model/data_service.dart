import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onlymens/core/globals.dart';

class AIModelDataService {
  // Placeholder for future AI model data service methods

  static Future<Map> fetchAIChats() async {
    final dataMap = {};
    await cloudDB
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('aiModelData')
        .get()
        .then((value) {
          for (var element in value.docs) {
            dataMap[element.id] = [element.data().keys.first, element.data()];
          }
        });
    print(dataMap.length);
    return dataMap;
  }

  static Future<void> updateAIChats(List msgs, String title) async {
    await cloudDB
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('aiModelData')
        .doc(DateTime.now().toString())
        .set({title: msgs}, SetOptions(merge: true));
    print('fetching');
  }

  Future<void> hardModeData() async {}
  Future<void> voiceModeData() async {}
}
