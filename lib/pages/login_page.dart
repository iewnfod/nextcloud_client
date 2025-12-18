import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud/provisioning_api.dart';
import 'package:nextcloud_client/constants.dart';
import 'package:nextcloud_client/http_client.dart';
import 'package:nextcloud_client/widgets/soft_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webdav_client/webdav_client.dart';

class LoginPage extends StatefulWidget {
  final void Function(NextcloudClient) setClient;
  final void Function(Client) setDavClient;

  const LoginPage({
    super.key,
    required this.setClient,
    required this.setDavClient,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _protocolController = TextEditingController(
    text: 'https://',
  );
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberPassword = false;
  bool _autoLogin = false;
  String _errorMessage = '';
  bool _isLoading = false;

  void login() async {
    if (_isLoading) return;

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    if (_urlController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _protocolController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields.';
        _isLoading = false;
      });
      return;
    }

    try {
      final client = NextcloudClient(
        Uri.parse(_protocolController.text + _urlController.text),
        loginName: _usernameController.text,
        appPassword: _passwordController.text,
        httpClient: UserAgentClient(USER_AGENT, http.Client()),
      );

      final user =
          (await client.provisioningApi.users.getCurrentUser()).body.ocs.data;
      print("Logged in as ${user.displayName}");

      final davClient = newClient(
        "${client.baseURL.origin}/remote.php/dav/files/${user.id}",
        user: _usernameController.text,
        password: _passwordController.text,
      );
      davClient.setHeaders({
        'accept-charset': 'utf-8',
        'User-Agent': USER_AGENT,
      });
      davClient.setConnectTimeout(8000);
      davClient.setSendTimeout(8000);
      await davClient.ping();
      print("WebDAV connection successful.");

      print("Saving data...");
      final prefs = await SharedPreferences.getInstance();
      prefs.setString("protocol", _protocolController.text);
      prefs.setString("url", _urlController.text);
      final storage = FlutterSecureStorage();
      await storage.write(key: "username", value: _usernameController.text);
      if (_rememberPassword) {
        await storage.write(key: "password", value: _passwordController.text);
      } else {
        await storage.delete(key: "password");
      }
      prefs.setBool("rememberPassword", _rememberPassword);
      prefs.setBool("autoLogin", _autoLogin);
      print("Data saved.");

      widget.setClient(client);
      widget.setDavClient(davClient);
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) async {
      final storage = FlutterSecureStorage();
      final username = await storage.read(key: "username");
      final password = await storage.read(key: "password");

      setState(() {
        _protocolController.text = prefs.getString("protocol") ?? 'https://';
        _urlController.text = prefs.getString("url") ?? '';
        _usernameController.text = username ?? '';
        _passwordController.text = password ?? '';
        _rememberPassword = prefs.getBool("rememberPassword") ?? false;
        _autoLogin = prefs.getBool("autoLogin") ?? false;
      });

      if (_autoLogin &&
          _urlController.text.isNotEmpty &&
          _usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty) {
        login();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Nextcloud')),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 400, maxHeight: 400),
          padding: const EdgeInsets.all(16.0),
          child: Flex(
            direction: .vertical,
            spacing: 10,
            children: [
              SizedBox(
                width: .maxFinite,
                child: Flex(
                  direction: .horizontal,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        readOnly: _isLoading,
                        controller: _protocolController,
                        decoration: const InputDecoration(
                          labelText: 'Protocol',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 8,
                      child: TextField(
                        readOnly: _isLoading,
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                readOnly: _isLoading,
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Login Name'),
              ),
              TextField(
                readOnly: _isLoading,
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'App Password'),
                obscureText: true,
              ),
              Flex(
                direction: .horizontal,
                mainAxisAlignment: .spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberPassword,
                        onChanged: (state) {
                          if (_isLoading) return;
                          setState(() {
                            _rememberPassword = state ?? !_rememberPassword;
                          });
                        },
                      ),
                      Text("Remember Password"),
                    ],
                  ),
                  if (_rememberPassword)
                    Row(
                      children: [
                        Checkbox(
                          value: _autoLogin,
                          onChanged: (state) {
                            if (_isLoading) return;
                            setState(() {
                              _autoLogin = state ?? !_autoLogin;
                            });
                          },
                        ),
                        Text("Auto Login"),
                      ],
                    ),
                ],
              ),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  maxLines: 3,
                  overflow: .ellipsis,
                ),
              Container(
                padding: const EdgeInsets.all(8.0),
                child: _isLoading
                    ? CircularProgressIndicator()
                    : SoftButton(
                        onPressed: login,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Flex(
                            direction: .horizontal,
                            mainAxisAlignment: .center,
                            crossAxisAlignment: .center,
                            children: [
                              Icon(Icons.login),
                              SizedBox(width: 10),
                              Transform.translate(
                                offset: const Offset(0, -2),
                                child: Text("Login"),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: "Do not have nextcloud server?"),
                    TextSpan(text: " "),
                    TextSpan(text: "Click "),
                    TextSpan(
                      text: "here",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(
                            Uri.parse(
                              "https://apps.nextcloud.com/apps/nextcloud_all_in_one",
                            ),
                          ).catchError((e) {
                            print("Could not launch URL: $e");
                            return true;
                          });
                        },
                    ),
                    TextSpan(text: " to learn how to create your own!"),
                  ],
                ),
                textAlign: .center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
