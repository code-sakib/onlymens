import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Legal")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =======================
            //   PRIVACY POLICY
            // =======================
            Text(
              "Privacy Policy",
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              """
This Privacy Policy describes how CleanMind handles your data.

1. **Information We Collect**
• Account information (email, name from Apple/Google sign-in).  
• Profile details you choose to add.  
• App usage data such as streaks and settings.  
• Posts, messages, and reports you send.

2. **How Your Data Is Used**
• To operate your CleanMind account.  
• To provide streak tracking and personalization.  
• To deliver community features such as posts and messaging.  
• To improve app quality, safety, and performance.

3. **How Your Data Is Stored**
• All data is stored securely in Firebase.  
• Your data is **encrypted in transit and at rest by Firebase**, but chats are not end-to-end encrypted.

4. **Content Blocking**
CleanMind uses Apple Screen Time APIs to block adult websites. We require Screen Time authorization to enable this feature. CleanMind never tracks or reads your browsing history.

5. **Reports & Feedback**
Reports and feedback may be linked to your account so we can address issues and protect the community.

6. **Sharing of Data**
We do not sell your personal information.  
We do not use third-party advertising SDKs.  
We only share data when legally required.

7. **Account Deletion**
You may delete your account at any time. All stored data will be permanently erased.

8. **Children's Privacy**
CleanMind is not intended for users under 16.

If you have any privacy concerns, please contact support through the app.
              """,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[300],
                height: 1.6,
              ),
            ),

            SizedBox(height: 40.h),

            // =======================
            //     TERMS OF USE
            // =======================
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
              """
By using CleanMind, you agree to the following terms.

1. **Purpose of the App**
CleanMind supports personal improvement through streak tracking, support tools, and optional community interactions. It is not a medical or therapeutic service.

2. **User Conduct**
You agree not to:  
• Post harmful, explicit, or abusive content.  
• Harass, threaten, or impersonate others.  
• Attempt to misuse or bypass app features.

3. **Subscriptions**
Some features require a paid subscription. Payments are handled through the App Store. Subscriptions automatically renew unless canceled in account settings.

4. **User-Generated Content**
Posts and messages you create may be removed if they violate community guidelines. Repeated violations may result in account restriction or removal.

5. **Content Blocking Feature**
Screen Time authorization is required to enable blocking of adult websites. CleanMind cannot guarantee complete blocking of all content.

6. **Limitation of Liability**
CleanMind provides tools for support and habit improvement but does not promise specific outcomes. Use the app at your own discretion.

7. **Modifications**
We may update these terms to improve clarity or comply with regulations. Continued use of the app means you accept the updated terms.

8. **Contact**
For any support or policy questions, contact us through the Help & Support section in the app.
              """,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[300],
                height: 1.6,
              ),
            ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}
