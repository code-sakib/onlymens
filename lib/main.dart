import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cleanmind/core/approuter.dart';
import 'package:cleanmind/core/apptheme.dart';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/firebase_options.dart';
import 'package:cleanmind/utilis/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  prefs = await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  

  runApp(
    BetterFeedback(
      theme: FeedbackThemeData(
        background: Colors.black.withOpacity(0.7),
        feedbackSheetColor: Colors.grey,
        drawColors: [Colors.red, Colors.blue, Colors.green, Colors.yellow],
        activeFeedbackModeColor: Colors.deepPurple,
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    hasInternet.then((value) {
      debugPrint(value ? 'Internet available' : 'No internet');
    });

    return ScreenUtilInit(
      designSize: const Size(390, 844), // iPhone 13 / Figma baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => SafeArea(
        child: MaterialApp.router(
          routerConfig: approutes,
          title: 'CleanMind',
          theme: AppTheme.theme,
          scaffoldMessengerKey: Utilis.messengerKey,
          debugShowCheckedModeBanner: false,
          useInheritedMediaQuery: true,
        ),
      ),
    );
  }
}

Future<void> seedFullLegalText() async {
  const String privacyFull = r'''
PRIVACY POLICY
Effective Date: November 1, 2025

Introduction
Welcome to CleanMind. We are committed to protecting your privacy and handling your data in an open and transparent manner. This Privacy Policy describes how CleanMind ("we," "us," or "our") collects, uses, stores, shares, and protects your personal information when you access or use our mobile application (the "App"). This Privacy Policy applies to all users of the App and governs our data collection and usage practices. By using CleanMind, you acknowledge that you have read and understood this Privacy Policy and agree to be bound by its terms.

Optional Data Collection (User-Provided Information)
The following information is collected only if you choose to provide it. You have full control over whether to share this information:

Account Information: If you choose to create an account or sign in to our App, we collect your email address and name as provided through your authentication method. You may choose to use the App without creating an account, though some features may be limited.

Profile Information: You may voluntarily provide additional profile details such as a username, display name, bio, profile picture, and other customizable profile elements. You have complete control over what information you choose to share in your profile and can edit or remove this information at any time through your account settings.

User-Generated Content: When you use community features, we collect and store the content you create, including posts, comments, messages, reports, feedback, and any other content you choose to share with the community. You are responsible for the content you post and should not share sensitive personal information publicly.

Progress and Settings Data: We store your personal progress information including streaks, goals, achievements, milestones, preferences, app settings, and any other data related to your use of the tracking features. This information is stored to provide you with a personalized experience and to help you track your personal development journey.

Communication Data: If you contact us directly through email, support channels, or feedback forms, we collect the information you provide in those communications, including your name, email address, message content, and any attachments you send.

Required Data Collection
Certain data is collected automatically to ensure the proper functioning, security, and improvement of our App. This data collection is mandatory and essential for providing our services:

Crash Analytics and Diagnostic Data: We automatically collect crash reports, error logs, diagnostic information, and performance metrics when the App experiences technical issues or malfunctions. This information helps us identify bugs, improve app stability, fix errors, and enhance the overall user experience. The diagnostic data may include device model, operating system version, app version, time and date of the crash, stack traces, memory usage, and other technical information related to the malfunction.

How We Use Your Information
We use the information we collect for various purposes related to providing, maintaining, improving, and protecting our services:

Service Delivery and Personalization: We use your account information and profile data to create and maintain your account, authenticate your identity, provide personalized features, track your progress and achievements, customize your experience based on your preferences, and enable you to participate in community features.

App Improvement and Development: We analyze crash analytics, diagnostic data, and usage statistics to identify and fix technical issues, improve app performance and stability, understand how users interact with our features, develop new features and functionality, optimize user experience, and make data-driven decisions about product development.

Communication: We may use your email address to send you important updates about the App, respond to your inquiries and support requests, notify you of changes to our terms or policies, send you information about new features or updates, and communicate regarding account-related matters. We will not send you promotional or marketing emails without your explicit consent.

Community Safety and Moderation: We review user-generated content, reports, and feedback to moderate community interactions, enforce our community guidelines and terms of service, respond to reports of inappropriate content or behavior, investigate potential violations, maintain a safe and supportive environment, and protect the rights and safety of our users.

Legal Compliance: We process your information as necessary to comply with applicable laws and regulations, respond to legal requests and prevent illegal activities, protect our rights and property, enforce our terms and policies, and fulfill our legal obligations.

Security: We use collected information to detect, prevent, and respond to fraud, abuse, security risks, and technical issues, to verify accounts and activity, and to promote safety and security across our services.


How We Store and Protect Your Information
Data Storage Infrastructure: All user data collected through our App is securely stored using Firebase Cloud Services, a cloud-based platform provided by Google LLC. Firebase employs industry-standard security measures to protect data stored on its servers. Your data is stored on servers located in secure data centers with redundant systems, backup procedures, and disaster recovery protocols.

Encryption: We rely on standard encryption provided by Firebase and Apple’s secure networking frameworks. All data is encrypted in transit via SSL/TLS and encrypted at rest using industry-standard mechanisms. **We do not implement any custom encryption methods**; instead, we rely fully on the built-in, platform-level encryption from Firebase and Apple to protect your information.

Security Measures: We maintain administrative, technical, and physical safeguards designed to protect your information against unauthorized access, destruction, loss, alteration, or misuse. However, no method of transmission over the internet or electronic storage is completely secure, and we cannot guarantee absolute security.

Data Retention: We retain your personal information for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law. When you delete your account, we immediately and permanently delete all associated data from our active systems. Some anonymized analytics data may be retained for statistical purposes.

Content Blocking Feature
CleanMind offers a content blocking feature designed to help you limit access to distracting or unwanted websites. This feature utilizes Apple's Screen Time API, which is a native iOS framework for managing and restricting device usage.

On-Device Functionality: The content blocking feature operates entirely on your local device. When you enable this feature and configure blocked websites, the restrictions are enforced by iOS Screen Time on your device. No browsing history, website visit data, or information about blocked or accessed sites is transmitted to our servers or stored by CleanMind.

Privacy Protection: We never see, track, monitor, collect, or have access to your browsing activity, website visits, or internet usage. The Screen Time API operates within the secure boundaries of your iOS device, and all blocking functionality is handled by Apple's operating system, not by our App.

Authorization Requirement: To use the content blocking feature, you must grant Screen Time authorization to CleanMind. This permission allows the App to configure Screen Time restrictions on your behalf. You can revoke this permission at any time through your device settings, though doing so will disable the content blocking functionality.

Limitations: While the content blocking feature is designed to be effective, we cannot guarantee that it will block all websites or that determined users cannot find ways to circumvent the restrictions. New websites are created regularly, and it may not be possible to maintain a comprehensive blocking list. The effectiveness of content blocking also depends on the proper configuration of Screen Time settings and device security.

Data Sharing and Third-Party Disclosure
No Sale of Personal Information: We do not sell, rent, trade, or otherwise transfer your personal information to third parties for monetary or other valuable consideration. Your data is not a commodity, and we are committed to keeping it private.

No Advertising Networks: We do not use third-party advertising networks, ad trackers, or marketing analytics platforms. We do not share your information with advertisers or allow third parties to track your behavior across apps or websites for advertising purposes.

Service Providers: We may share limited information with trusted third-party service providers who assist us in operating our App and providing our services. Currently, we use Firebase (operated by Google LLC) for cloud storage, authentication, and crash analytics. These service providers are bound by contractual obligations to keep your information confidential and use it only for the purposes for which we disclose it to them.

Legal Requirements: We may disclose your information if required to do so by law or in response to valid requests by public authorities, such as to comply with a subpoena, court order, or legal process, to protect our rights, property, or safety, to investigate fraud or security issues, to respond to government requests, or when we believe disclosure is necessary to prevent harm or illegal activity.

Business Transfers: In the event of a merger, acquisition, reorganization, bankruptcy, or sale of assets, your information may be transferred as part of that transaction. We will notify you via email or prominent notice in the App before your information is transferred and becomes subject to a different privacy policy.

Aggregated and Anonymized Data: We may share aggregated, anonymized, or de-identified information that cannot reasonably be used to identify you. Such data may be used for research, analysis, or other purposes without restriction.

Your Rights and Choices
You have certain rights regarding your personal information, and we provide you with the ability to exercise these rights as described below:

Right to Access: You have the right to request information about what personal data we hold about you. This includes the categories of data we collect, the purposes for which we use it, the recipients with whom we share it, and the retention period. You can request a copy of your personal data by contacting us at the email address provided below.

Right to Rectification: You have the right to request correction of inaccurate or incomplete personal data. You can update most of your profile information directly through the App settings. For other corrections, please contact us.

Right to Deletion: You have the right to request deletion of your personal data. You can delete your account at any time through the Profile settings in the App. Upon account deletion, all your data including your profile, posts, progress, and settings will be permanently removed from our systems immediately and cannot be recovered.

Right to Restriction of Processing: You have the right to request that we restrict the processing of your personal data under certain circumstances, such as when you contest the accuracy of the data or object to our processing.

Right to Data Portability: You have the right to receive your personal data in a structured, commonly used, and machine-readable format and to transmit that data to another service provider. To request your data in a portable format, please contact us.

Right to Object: You have the right to object to our processing of your personal data for certain purposes, particularly for direct marketing purposes or processing based on legitimate interests. We do not currently engage in direct marketing, but you may object to other forms of processing by contacting us.

Right to Withdraw Consent: Where we process your personal data based on your consent, you have the right to withdraw that consent at any time. This will not affect the lawfulness of processing based on consent before its withdrawal. You can withdraw consent by adjusting your settings in the App or by contacting us.

Right to Lodge a Complaint: You have the right to lodge a complaint with a data protection supervisory authority in your jurisdiction if you believe that our processing of your personal data violates applicable data protection laws.

Exercising Your Rights: To exercise any of these rights, please contact us at cleanmind001@gmail.com. We will respond to your request within a reasonable timeframe and in accordance with applicable law. We may need to verify your identity before processing your request to ensure the security of your personal information.

Children's Privacy
CleanMind is intended for use by individuals who are at least 18 years of age. We do not knowingly collect, solicit, or maintain personal information from anyone under the age of 18, nor do we knowingly allow such persons to create accounts or use our services.

If we learn that we have collected personal information from a child under 18 without verification of parental consent, we will take steps to delete that information as quickly as possible. If you believe that we might have collected information from or about a child under 18, please contact us immediately at cleanmind001@gmail.com.

Parents and guardians should supervise their children's online activities and help enforce this Privacy Policy by instructing their children never to provide personal information through the App without permission.

International Data Transfers
Your information may be transferred to, stored, and processed in countries other than your country of residence, including the United States, where our service providers operate. These countries may have data protection laws that are different from the laws of your country.

When we transfer your personal information internationally, we ensure appropriate safeguards are in place to protect your data in accordance with this Privacy Policy and applicable data protection laws. These safeguards may include the use of standard contractual clauses approved by relevant authorities or ensuring that the recipient is certified under an approved certification mechanism.

Cookies and Tracking Technologies
Our App does not use cookies or similar tracking technologies for advertising or marketing purposes. We may use essential cookies or similar technologies necessary for the functionality of the App, such as maintaining your logged-in state or storing your preferences. These technologies do not track your activity across other apps or websites.

Changes to This Privacy Policy
We may update this Privacy Policy from time to time to reflect changes in our practices, technology, legal requirements, or other factors. When we make changes, we will update the "Effective Date" at the top of this Privacy Policy.

We will notify you of any material changes by posting a notice in the App, sending you an email notification, or by other appropriate means. We encourage you to review this Privacy Policy periodically to stay informed about how we collect, use, and protect your information.

Your continued use of the App after the effective date of an updated Privacy Policy constitutes your acceptance of the revised policy. If you do not agree to the updated Privacy Policy, you should stop using the App and may delete your account.

Contact Information
If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us at:

Email: cleanmind001@gmail.com

You may also use the Help & Support option available in your Profile settings within the App to reach our support team.

We are committed to resolving any privacy concerns you may have and will respond to your inquiry within a reasonable timeframe.

END OF PRIVACY POLICY
''';

  const String termsFull = r'''
TERMS OF USE
Effective Date: November 1, 2025

Introduction and Acceptance of Terms
Welcome to CleanMind. These Terms of Use ("Terms") constitute a legally binding agreement between you and CleanMind ("we," "us," or "our") governing your access to and use of the CleanMind mobile application (the "App") and all related services, features, and content.

By downloading, installing, accessing, or using the App, you acknowledge that you have read, understood, and agree to be bound by these Terms and our Privacy Policy. If you do not agree to these Terms, you must not access or use the App.

We reserve the right to modify these Terms at any time, and your continued use of the App following any changes constitutes acceptance of those changes. It is your responsibility to review these Terms periodically.

Description and Purpose of the App
CleanMind is a personal growth and wellness application designed to help users track their progress, set and achieve goals, build positive habits, and connect with supportive communities. The App provides various features including progress tracking, goal setting, streak monitoring, community forums, and content blocking tools.

Not Medical or Therapeutic Services: CleanMind is not a medical device, therapeutic service, mental health treatment, or substitute for professional medical advice, diagnosis, or treatment. The App is designed for general wellness and personal development purposes only. The information and features provided through the App are not intended to diagnose, treat, cure, or prevent any disease or medical condition.

Consult Healthcare Professionals: Always seek the advice of your physician, therapist, or other qualified healthcare provider with any questions you may have regarding a medical condition, mental health concern, or addiction. Never disregard professional medical advice or delay seeking it because of something you have read or experienced in the App.

Emergency Situations: If you are experiencing a medical or mental health emergency, including thoughts of self-harm or suicide, immediately call emergency services or contact a crisis helpline. CleanMind is not equipped to handle emergency situations.

Eligibility and Account Requirements
Age Requirement: You must be at least 18 years of age to create an account and use CleanMind. By using the App, you represent and warrant that you are 18 years of age or older and have the legal capacity to enter into these Terms. We do not knowingly collect information from or direct any of our services to individuals under 18.

Account Registration: Some features of the App may require you to create an account. When creating an account, you agree to provide accurate, current, and complete information and to maintain and update this information to keep it accurate, current, and complete. You are responsible for safeguarding your account credentials and for any activities or actions under your account.

Account Security: You must immediately notify us of any unauthorized use of your account or any other breach of security. We are not liable for any loss or damage arising from your failure to comply with these security obligations.

One Account Per User: You may only create and maintain one account. Creating multiple accounts to circumvent restrictions or for any fraudulent purpose is strictly prohibited and may result in termination of all your accounts.

Community Guidelines and Acceptable Use
To maintain a safe, supportive, and respectful environment for all users, you agree to abide by the following community guidelines and acceptable use policies:

Respectful Conduct: You will treat all users with kindness, respect, and dignity. Harassment, bullying, intimidation, threats, hate speech, discrimination, or any form of abusive behavior toward other users or groups is strictly prohibited.

Appropriate Content: You will not post, upload, share, or transmit content that is illegal, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, pornographic, sexually explicit, violent, hateful, or racially, ethnically, or otherwise objectionable. This includes content that promotes or glorifies self-harm, eating disorders, substance abuse, or dangerous activities.

No Impersonation: You will not impersonate any person or entity, falsely state or misrepresent your affiliation with any person or entity, or use a false identity with the intent to mislead others.

No Spam or Manipulation: You will not post spam, engage in vote manipulation, artificially inflate engagement metrics, or engage in any deceptive practices. You will not post repetitive content, unsolicited promotions, or irrelevant information.

Intellectual Property: You will not post content that infringes on the intellectual property rights, privacy rights, or other rights of any third party. You must have the right to share any content you post.

Legal Compliance: You will comply with all applicable local, state, national, and international laws and regulations in your use of the App.

No System Abuse: You will not attempt to gain unauthorized access to any portion of the App, other users' accounts, or any systems or networks connected to the App. You will not interfere with or disrupt the App's functionality, servers, or networks, or violate any security measures.

Proper Use of Features: You will use the features of the App as intended and will not attempt to exploit, circumvent, or manipulate any features, systems, or policies.

Content Ownership and License
Your Content: You retain all ownership rights to the content you create, post, or upload to the App, including posts, comments, messages, and other user-generated content ("Your Content"). However, by posting Your Content on or through the App, you grant us a worldwide, non-exclusive, royalty-free, transferable, sublicensable license to use, copy, modify, distribute, publicly display, and perform Your Content in connection with operating and providing the App and our services.

Responsibility for Your Content: You are solely responsible for Your Content and the consequences of posting or publishing it. You represent and warrant that you own or have the necessary rights, licenses, consents, and permissions to grant the license described above and that Your Content does not violate these Terms, any applicable laws, or the rights of any third party.

Our Content: The App and its entire contents, features, functionality, and design, including but not limited to all text, graphics, images, software, and other material (excluding Your Content), are owned by CleanMind, our licensors, or other providers and are protected by copyright, trademark, patent, trade secret, and other intellectual property laws.

Limited License to Use: We grant you a limited, non-exclusive, non-transferable, non-sublicensable, revocable license to access and use the App for your personal, non-commercial use in accordance with these Terms. This license does not include any right to use data mining, robots, or similar data gathering or extraction methods, or any right to copy, modify, reverse engineer, or create derivative works of the App.

Content Moderation and Enforcement
Right to Moderate: We reserve the right, but do not assume the obligation, to monitor, review, edit, or remove any user-generated content at our sole discretion for any reason, including if we determine that the content violates these Terms, our community guidelines, or is otherwise objectionable.

Reporting Violations: Users are encouraged to report content or behavior that violates these Terms or community guidelines. We will review reported content and take appropriate action, which may include removing the content, issuing warnings, or suspending or terminating accounts.

Warnings and Account Actions: Violations of these Terms or community guidelines may result in warnings, temporary suspension, or permanent termination of your account, depending on the severity and frequency of the violations. We reserve the right to take these actions at our sole discretion without prior notice.

No Liability for User Content: We are not responsible for user-generated content posted on the App. We do not endorse any opinions, recommendations, or advice expressed by users, and we expressly disclaim any and all liability in connection with user-generated content.

Content Blocking Feature
Feature Description: CleanMind offers a content blocking feature that utilizes Apple's Screen Time API to help you restrict access to certain websites or categories of content that you find distracting or wish to avoid.

Device-Level Functionality: The content blocking feature operates at the device level through iOS Screen Time. When you configure blocked websites or content categories, these restrictions are enforced by your device's operating system, not by CleanMind servers.

Screen Time Authorization: To use this feature, you must grant CleanMind permission to configure Screen Time settings on your device. You can revoke this permission at any time through your device settings, though doing so will disable the content blocking functionality.

No Monitoring: CleanMind does not monitor, track, collect, or have access to your browsing history, website visits, or internet activity. The content blocking feature works entirely on your device, and no browsing data is transmitted to our servers.

Effectiveness and Limitations: While the content blocking feature is designed to be effective, we make no guarantees that it will block all unwanted content or websites. New websites are created regularly, and blocking lists may not be comprehensive or up-to-date. Determined users may find ways to circumvent restrictions. The effectiveness of the feature depends on proper device configuration and security settings.

User Responsibility: You are responsible for properly configuring and managing the content blocking feature. You acknowledge that this feature is a tool to assist with self-regulation and that ultimate responsibility for your device usage and internet activity rests with you.

No Liability: We are not liable for any content that is not successfully blocked, for any consequences arising from the use or failure of the content blocking feature, or for any circumvention of blocking restrictions.

Disclaimer of Warranties
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE APP AND ALL CONTENT AND SERVICES PROVIDED THROUGH THE APP ARE PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.

WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, SECURE, OR ERROR-FREE, THAT DEFECTS WILL BE CORRECTED, OR THAT THE APP OR THE SERVERS THAT MAKE IT AVAILABLE ARE FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS.

WE MAKE NO WARRANTIES OR REPRESENTATIONS ABOUT THE ACCURACY, COMPLETENESS, OR TIMELINESS OF ANY CONTENT PROVIDED THROUGH THE APP OR THE RESULTS THAT MAY BE OBTAINED FROM USING THE APP. WE DO NOT WARRANT THAT THE APP WILL MEET YOUR REQUIREMENTS OR EXPECTATIONS.

YOUR USE OF THE APP IS AT YOUR OWN RISK. ANY MATERIAL DOWNLOADED OR OTHERWISE OBTAINED THROUGH THE USE OF THE APP IS ACCESSED AT YOUR OWN DISCRETION AND RISK, AND YOU WILL BE SOLELY RESPONSIBLE FOR ANY DAMAGE TO YOUR DEVICE OR LOSS OF DATA THAT RESULTS FROM THE DOWNLOAD OR USE OF ANY SUCH MATERIAL.

Limitation of Liability
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL CLEANMIND, ITS OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, LICENSORS, OR SERVICE PROVIDERS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO LOSS OF PROFITS, DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES, RESULTING FROM:

(A) YOUR ACCESS TO, USE OF, OR INABILITY TO ACCESS OR USE THE APP;
(B) ANY CONDUCT OR CONTENT OF ANY THIRD PARTY ON THE APP, INCLUDING WITHOUT LIMITATION ANY DEFAMATORY, OFFENSIVE, OR ILLEGAL CONDUCT OF OTHER USERS OR THIRD PARTIES;
(C) ANY CONTENT OBTAINED FROM THE APP;
(D) UNAUTHORIZED ACCESS, USE, OR ALTERATION OF YOUR TRANSMISSIONS OR CONTENT;
(E) ANY OTHER MATTER RELATING TO THE APP,

WHETHER BASED ON WARRANTY, CONTRACT, TORT (INCLUDING NEGLIGENCE), PRODUCT LIABILITY, OR ANY OTHER LEGAL THEORY, AND WHETHER OR NOT WE HAVE BEEN INFORMED OF THE POSSIBILITY OF SUCH DAMAGE, AND EVEN IF A REMEDY SET FORTH HEREIN IS FOUND TO HAVE FAILED OF ITS ESSENTIAL PURPOSE.

IN NO EVENT SHALL OUR AGGREGATE LIABILITY FOR ALL CLAIMS RELATING TO THE APP EXCEED THE GREATER OF ONE HUNDRED DOLLARS ($100) OR THE AMOUNT YOU PAID US, IF ANY, IN THE PAST TWELVE MONTHS.

SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OR LIMITATION OF INCIDENTAL OR CONSEQUENTIAL DAMAGES, SO THE ABOVE LIMITATIONS MAY NOT APPLY TO YOU.

Indemnification
You agree to defend, indemnify, and hold harmless CleanMind, its parent company, officers, directors, employees, agents, licensors, and service providers from and against any claims, liabilities, damages, judgments, awards, losses, costs, expenses, or fees (including reasonable attorneys' fees) arising out of or relating to:

(A) Your violation of these Terms;
(B) Your use of the App, including but not limited to your user-generated content, any use of the App's content, services, and features other than as expressly authorized in these Terms;
(C) Your violation of any rights of another party, including any other users of the App;
(D) Your violation of any applicable laws, rules, or regulations.

We reserve the right to assume the exclusive defense and control of any matter otherwise subject to indemnification by you, in which event you will assist and cooperate with us in asserting any available defenses.

Termination
Termination by You: You may terminate your account and stop using the App at any time by following the account deletion process in the Profile settings. Upon termination, your right to use the App will immediately cease, and all your data will be permanently deleted as described in our Privacy Policy.

Termination by Us: We reserve the right to suspend or terminate your access to the App, with or without notice, for any reason, including but not limited to:

(A) Violation of these Terms or our community guidelines;
(B) Fraudulent, abusive, or illegal activity;
(C) Extended periods of inactivity;
(D) At our sole discretion for any other reason.

Effects of Termination: Upon termination of your account, whether by you or by us, your right to access and use the App will immediately cease. All provisions of these Terms that by their nature should survive termination shall survive, including but not limited to ownership provisions, warranty disclaimers, indemnity obligations, and limitations of liability.

No Refunds: If your account is terminated for violation of these Terms, you will not be entitled to any refund of fees paid, if any.

Updates and Modifications to the App
We reserve the right to modify, suspend, or discontinue the App or any features or functionality thereof at any time, with or without notice, for any reason. We may also impose limits on certain features and services or restrict your access to parts or all of the App without notice or liability.

We may release updates, patches, or new versions of the App from time to time. These updates may be necessary to maintain compatibility, fix bugs, add features, or address security vulnerabilities. You may need to update your version of the App to continue using it. Some updates may be required and automatically downloaded and installed.

Changes to These Terms
We reserve the right to modify these Terms at any time. If we make material changes to these Terms, we will notify you by posting a notice in the App, sending an email to the address associated with your account, or through other appropriate means prior to the changes taking effect.

Your continued use of the App after the effective date of revised Terms constitutes your acceptance of those changes. If you do not agree to the modified Terms, you must stop using the App and may delete your account.

It is your responsibility to review these Terms periodically. The "Effective Date" at the top of these Terms indicates when they were last updated.

Governing Law and Dispute Resolution
These Terms and any dispute or claim arising out of or related to these Terms or your use of the App shall be governed by and construed in accordance with the laws of the jurisdiction in which CleanMind operates, without regard to its conflict of law provisions.

Informal Resolution: Before filing a claim, you agree to try to resolve the dispute informally by contacting us at cleanmind001@gmail.com. We will try to resolve the dispute informally by contacting you via email. If a dispute is not resolved within 60 days after submission, you or we may bring a formal proceeding.

Jurisdiction and Venue: You agree that any legal action or proceeding arising out of or related to these Terms or the App shall be instituted exclusively in the courts located in the jurisdiction where CleanMind operates, and you irrevocably submit to the jurisdiction of such courts and waive any objection to venue in such courts.

Class Action Waiver: To the extent permitted by law, you and CleanMind agree that each may bring claims against the other only in an individual capacity and not as a plaintiff or class member in any purported class or representative proceeding.

Miscellaneous Provisions
Entire Agreement: These Terms, together with our Privacy Policy, constitute the entire agreement between you and CleanMind regarding your use of the App and supersede all prior and contemporaneous agreements, proposals, or representations, written or oral, concerning the subject matter herein.

Severability: If any provision of these Terms is found to be unlawful, void, or unenforceable, that provision shall be deemed severable from these Terms and shall not affect the validity and enforceability of any remaining provisions.

Waiver: Our failure to enforce any right or provision of these Terms will not be considered a waiver of those rights or provisions. No waiver of any provision of these Terms shall be deemed a further or continuing waiver of such provision or any other provision.

Assignment: You may not assign or transfer these Terms or your rights and obligations under these Terms without our prior written consent. We may assign or transfer these Terms or any rights or obligations hereunder at any time without restriction and without notice.

Exceptional Majeure: We shall not be liable for any failure or delay in performance under these Terms due to causes beyond our reasonable control, including but not limited to acts of God, war, terrorism, riots, embargoes, acts of civil or military authorities, fire, floods, accidents, network infrastructure failures, strikes, or shortages of transportation facilities, fuel, energy, labor, or materials.

Headings: The section headings in these Terms are for convenience only and have no legal or contractual effect.

Language: These Terms may be translated into other languages for your convenience. In the event of any conflict or inconsistency between the English version and any translated version, the English version shall prevail.

Contact Information and Support
If you have any questions, concerns, or feedback regarding these Terms, the App, or our services, please contact us:

Email: cleanmind001@gmail.com

You may also use the Help & Support option available in your Profile settings within the App to reach our support team directly.

We are committed to addressing your inquiries and concerns promptly and will respond within a reasonable timeframe.

Thank you for using CleanMind. We are committed to supporting your personal growth journey while protecting your privacy and maintaining a safe, supportive community.

END OF TERMS OF USE
''';

  try {
    await FirebaseFirestore.instance.collection("privacy").doc("legal").set({
      "lastUpdated": "November 2025",
      "effectiveDate": "November 1, 2025",
      "privacy_full": privacyFull,
      "terms_full": termsFull,
    });

    debugPrint("🔥 FULL legal text uploaded to Firebase successfully.");
  } catch (e) {
    debugPrint("❌ Error seeding legal text: $e");
  }
}
