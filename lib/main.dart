import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud_client/constants.dart';
import 'package:nextcloud_client/pages/default_page.dart';
import 'package:nextcloud_client/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nextcloud Client',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurpleAccent),
        fontFamily: Platform.isWindows ? '微软雅黑' : null,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  NextcloudClient? _client;
  Client? _davClient;

  void setClient(NextcloudClient client) {
    setState(() {
      _client = client;
    });
  }

  void setDavClient(Client davClient) {
    setState(() {
      _davClient = davClient;
    });
  }

  void logout() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove("autoLogin");

      final storage = FlutterSecureStorage();
      storage.delete(key: "password").then((_) {
        setState(() {
          _client = null;
        });
      });
    });
  }

  String? _bg() {
    if (_client == null) {
      return null;
    }
    return "${_client!.baseURL.origin}/index.php/apps/theming/image/background";
  }

  @override
  Widget build(BuildContext context) {
    if (_client != null && _davClient != null) {
      return Container(
        decoration: BoxDecoration(
          image: _bg() == null
              ? null
              : DecorationImage(
                  image: CachedNetworkImageProvider(
                    _bg()!,
                    headers: {'User-Agent': USER_AGENT},
                  ),
                  fit: BoxFit.cover,
                ),
        ),
        child: DefaultPage(
          client: _client!,
          davClient: _davClient!,
          logout: logout,
        ),
      );
    } else {
      return LoginPage(setClient: setClient, setDavClient: setDavClient);
    }
  }
}
