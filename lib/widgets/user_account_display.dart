import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud_client/constants.dart';
import 'package:nextcloud_client/widgets/soft_button.dart';

class UserAccountDisplay extends StatelessWidget {
  final String? displayName;
  final String? status;
  final String? icon;
  final String? email;
  final void Function() logout;

  const UserAccountDisplay({
    super.key,
    required this.displayName,
    required this.status,
    required this.icon,
    required this.email,
    required this.logout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon == null
            ? Icon(Icons.account_circle, size: 64)
            : Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(
                      icon!,
                      headers: {"User-Agent": USER_AGENT},
                    ),
                  ),
                ),
              ),
        displayName == null
            ? Text("Unknown User")
            : Text(
                displayName!,
                style: const TextStyle(fontSize: 20, fontWeight: .bold),
              ),
        email == null
            ? Text("")
            : Text(email!, style: const TextStyle(fontSize: 16)),
        status == null ? Text("") : Text("Status: $status"),

        SizedBox(height: 20),

        Padding(
          padding: EdgeInsets.only(left: 16, right: 16),
          child: SoftButton(
            onPressed: () {
              logout();
            },
            color: Colors.red,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Flex(
                direction: .horizontal,
                mainAxisAlignment: .center,
                crossAxisAlignment: .center,
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 10),
                  Transform.translate(
                    offset: const Offset(0, -2),
                    child: Text(
                      "Logout",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
