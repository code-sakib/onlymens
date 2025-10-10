import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:onlymens/user_model.dart';

class BWBPage extends StatelessWidget {
  const BWBPage({super.key});
  static UsersFriendsListModel usersFriendsList = UsersFriendsListModel(
    brand: 'brand',
    img: 'img',
    interested: 'interested',
    uploader: 'uploader',
    offer: 'offer',
    checkOffer: 'checkOffer',
    interestedUsers: ['interestedUsers'],
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Find people on the same journey'),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    CupertinoIcons.person_2_fill,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: usersFriendsList.interestedUsers?.length ?? 0,
              itemBuilder: (context, index) {
                return GestureDetector(
                  // onTap: () => context.('chat', extra: user),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: ListTile(
                        leading: UserImgFetching(
                          user: UserModel(name: 'name', uID: 'user1'),
                        ),
                        title: Text('name'),
                        subtitle: Text('let grow together'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UserImgFetching extends StatefulWidget {
  const UserImgFetching({super.key, required this.user});

  final UserModel user;

  @override
  _UserImgFetchingState createState() => _UserImgFetchingState();
}

class _UserImgFetchingState extends State<UserImgFetching> {
  final String fallbackImageUrl =
      'https://cdn-icons-png.flaticon.com/512/2815/2815428.png'; // Fallback image URL

  String currentImageUrl = ''; // Holds the URL to display

  static late bool isImgNull;

  @override
  void initState() {
    super.initState();
    isImgNull = widget.user.dp == null;

    if (isImgNull) return;

    currentImageUrl = widget.user.dp!; // Start with the primary image URL
  }

  @override
  Widget build(BuildContext context) {
    return !isImgNull
        ? CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(currentImageUrl),
            onBackgroundImageError: (error, stackTrace) {
              // Switch to fallback URL if primary image fails
              setState(() {
                currentImageUrl = fallbackImageUrl;
              });
            },
          )
        : CircleAvatar(
            radius: 25,
            child: Text(widget.user.name[0].toUpperCase()),
          );
  }
}
