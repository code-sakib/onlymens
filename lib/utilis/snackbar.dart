import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:onlymens/core/apptheme.dart';

class Utilis {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static showSnackBar(String msg, {bool isErr = false}) {
    final snackBar = SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating, // ✅ Floating instead of bottom bar
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isErr
          ? const Color(0xFFEF9A9A)
          : const Color(0xFFB5A8F5),
      duration: const Duration(seconds: 2),
      elevation: 2,
    );

    messengerKey.currentState!
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static showLoading([bool toShow = true]) {
    toShow
        ? WidgetsBinding.instance.addPostFrameCallback(
            (timeStamp) => SnackBar(
              content: Row(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(width: 16),
                  Text('Loading...', style: TextStyle(color: AppColors.text)),
                ],
              ),
            ),
          )
        : messengerKey.currentState!.removeCurrentSnackBar();
  }

  static showToast(String msg, {bool isErr = false}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: !isErr ? AppColors.primary : const Color(0xFFEF9A9A),
      fontSize: 16.0,
    );
  }
}
