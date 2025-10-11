import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onlymens/core/app_error.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/utilis/snackbar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isContentBlocked = true;
  final TextEditingController _confirmationController = TextEditingController();

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  void _showToggleOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disable Content Block?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To disable content blocking, please type:',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[700]!),
                ),
                child: Text(
                  'I choose to stay in apathy, embrace destructive thoughts, and avoid personal growth',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[300],
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _confirmationController,
                maxLines: 3,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type the text above...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _confirmationController.clear();
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (_confirmationController.text.trim() ==
                    'I wanna stay where I\'m in apathy, destructive thoughts and don\'t grow in life') {
                  setState(() {
                    _isContentBlocked = false;
                  });
                  _confirmationController.clear();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Content blocking disabled'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Text doesn\'t match. Please try again.'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              },
              child: Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _handleToggleChange(bool value) {
    if (value) {
      // Turning on - no confirmation needed
      setState(() {
        _isContentBlocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Content blocking enabled'),
          backgroundColor: Colors.green[700],
        ),
      );
    } else {
      // Turning off - show confirmation dialog
      _showToggleOffDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],

      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(CupertinoIcons.back),
        ),
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              width: double.infinity,
              color: Colors.grey[850],
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  // Avatar Image
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.deepPurple, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/3d/lvl3.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[700],
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Name
                  Text(
                    'Sakib Shaikh',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Level Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.deepPurple, width: 1),
                    ),
                    child: Text(
                      'Level 3 - On Track',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple[200],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Days Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Day 10 of 22',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Statistics Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Streak',
                        '11 Days',
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                      _buildStatItem(
                        'Progress',
                        '45%',
                        Icons.trending_up,
                        Colors.green,
                      ),
                      _buildStatItem(
                        'Goals',
                        '12/20',
                        Icons.flag,
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Account Settings Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  _buildSettingsItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  _buildSettingsItem(
                    icon: Icons.lock,
                    title: 'Privacy',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Content Block Toggle Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isContentBlocked
                          ? Colors.green[900]?.withOpacity(0.3)
                          : Colors.red[900]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isContentBlocked
                            ? Colors.green[700]!
                            : Colors.red[700]!,
                      ),
                    ),
                    child: Icon(
                      Icons.shield,
                      color: _isContentBlocked
                          ? Colors.green[400]
                          : Colors.red[400],
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Block Restrictive Content',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This will block all inappropriate web or browser activity',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isContentBlocked,
                    onChanged: _handleToggleChange,
                    activeThumbColor: Colors.green[600],
                    activeTrackColor: Colors.green[800],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Preferences Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: 'English',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  _buildSettingsItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  _buildSettingsItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Sign Out Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  // Show confirmation dialog for sign out
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: Colors.grey[850],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Sign Out?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          'Are you sure you want to sign out?',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                            ),
                            onPressed: () async {
                              // Add sign out logic here
                              try {
                                isGuest = false; // Reset guest mode
                                await auth.signOut();
                                if (context.mounted) {
                                  context.go('/'); // Correct route
                                }
                                Utilis.showSnackBar('Signed out successfully');
                              } on AppError catch (e) {
                                if (context.mounted) {
                                  Utilis.showSnackBar(
                                    e.userMessage,
                                    isErr: true,
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple[300]),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      trailing: trailing != null
          ? Text(
              trailing,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            )
          : Icon(Icons.chevron_right, color: Colors.grey[600]),
      onTap: onTap,
    );
  }
}
