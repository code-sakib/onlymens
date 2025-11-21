import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String? privacyText;
  String? termsText;
  String? lastUpdated;
  String? effectiveDate;

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchLegal();
  }

  Future<void> _fetchLegal() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('privacy')
          .doc('legal')
          .get();

      if (!doc.exists) {
        setState(() {
          error = "Legal document not found";
          loading = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        privacyText = data['privacy_full'] ?? 'No privacy policy available.';
        termsText = data['terms_full'] ?? 'No terms available.';
        lastUpdated = data['lastUpdated'] ?? 'N/A';
        effectiveDate = data['effectiveDate'] ?? 'N/A';
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Failed to load content";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Privacy Policy • Terms",
            style: TextStyle(fontSize: 18.sp, color: Colors.white),
          ),
          subtitle: Text(
            "Last updated: ${lastUpdated ?? '---'}",
            style: TextStyle(fontSize: 11.sp, color: Colors.grey),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
          : error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.grey, size: 40.sp),
          SizedBox(height: 12.h),
          Text(
            error!,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              setState(() {
                loading = true;
                error = null;
              });
              _fetchLegal();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            privacyText!,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[300],
              height: 1.6,
            ),
          ),

          SizedBox(height: 40.h),

          // TERMS
          Text(
            "Terms of Use",
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          SizedBox(height: 16.h),
          Text(
            termsText!,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[300],
              height: 1.6,
            ),
          ),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}
