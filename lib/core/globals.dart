import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onlymens/core/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Generals

bool isGuest = false;

//Firebase

final FirebaseAuth auth = FirebaseAuth.instance;

FirebaseFirestore  cloudDB = FirebaseFirestore.instance;

//Currentuser
late CurrentUser currentUser;

//
late SharedPreferences prefs; 

  
