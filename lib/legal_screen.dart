import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: ListTile(
          title: Text(
            "Privacy Policy • Terms",
            style: TextStyle(fontSize: 18.sp),
          ),
          subtitle: Text(
            "Last updated: November 2025",
            style: TextStyle(fontSize: 11.sp, color: Colors.grey),
          ),
        ),
      ),
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

            SizedBox(height: 8.h),

            Text(
              "Effective: November 1, 2025",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
            ),

            SizedBox(height: 16.h),

            Text(
              """
This Privacy Policy describes how CleanMind handles your data.

1. **Information We Collect**
- Basic account info (email and name from sign-in).  
- Profile details you can edit (username, profile picture).  
- Your progress data (streaks, goals, and app settings).  
- Community content you create, such as posts.

2. **How Your Data Is Used**
- To personalize your experience and track your progress.  
- To enable community features like posts and support messages.  
- To respond to your feedback and improve the app.  
- To keep the community safe and supportive.

3. **How Your Data Is Stored**
- All data is securely stored in Firebase (Cloud Storage).  
- Your data is **encrypted and protected** by industry-standard security.  
- Profile pictures are stored locally on your device only.

4. **Content Blocking**
CleanMind uses Apple's Screen Time API to help you block distracting websites. This feature works entirely on your device — **we never see or track what you browse**. Screen Time authorization is required to enable this feature.

5. **Community Safety**
If you report content or send feedback, we review it to block and improve the app and keep the community safe. This helps us respond to issues and support all users better.

6. **Sharing of Data**
- We **never sell** your personal information.  
- We **don't use** advertising trackers or third-party analytics.  

7. **Account Deletion**
You can delete your account anytime from Profile settings. **All your data will be permanently removed immediately**, including your profile, posts, and progress.

8. **Children's Privacy**
CleanMind is designed for users 18 and older. We don't knowingly collect information from anyone under 18.
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

            SizedBox(height: 8.h),

            Text(
              "Effective: November 1, 2025",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
            ),

            SizedBox(height: 16.h),

            Text(
              """
By using CleanMind, you agree to the following terms.

1. **Purpose of the App**
CleanMind is a personal growth tool for tracking progress and connecting with supportive communities. **It's not a medical or therapeutic service** — please consult healthcare professionals for medical advice.

2. **Community Guidelines**
To keep CleanMind safe and supportive, please:  
- Be kind and respectful to others.  
- Avoid posting harmful, explicit, or inappropriate content.  
- Don't harass, bully, or impersonate anyone.  
- Use features as intended, without attempting to exploit or bypass them.

3. **Content Moderation**
Posts or messages that violate community guidelines may be removed. Repeated violations could lead to warnings or account restrictions to protect the community.

4. **Content Blocking Feature**
The content blocking feature uses iOS Screen Time and works on your device. While it's effective, **we can't guarantee it blocks everything**, as new sites appear regularly.

5. **Updates to Terms**
We may update these terms occasionally to improve clarity or meet legal requirements. We'll notify you of major changes through the app.

6. **Get Help**
Questions? Feedback? Reach out anytime:  
**cleanmind001@gmail.com**

You can also use the Help & Support option in your Profile settings.
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
