import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Generals

bool isGuest = false;

//Firebase

final FirebaseAuth auth = FirebaseAuth.instance;

FirebaseFirestore cloudDB = FirebaseFirestore.instance;

//Currentuser
late User currentUser;

//
late SharedPreferences prefs;


//net
final Future<bool> hasInternet = InternetConnection().hasInternetAccess;
