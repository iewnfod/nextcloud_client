import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud/provisioning_api.dart';
import 'package:nextcloud/user_status.dart';
import 'package:nextcloud_client/constants.dart';
import 'package:nextcloud_client/download_manager.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:nextcloud_client/widgets/file_tabs.dart';
import 'package:nextcloud_client/widgets/user_account_display.dart';
import 'package:webdav_client/webdav_client.dart';

class DefaultPage extends StatefulWidget {
  final NextcloudClient client;
  final Client davClient;
  final void Function() logout;

  const DefaultPage({
    super.key,
    required this.client,
    required this.davClient,
    required this.logout,
  });

  @override
  State<DefaultPage> createState() => _DefaultPageState();
}

class _DefaultPageState extends State<DefaultPage> {
  UserDetails? _user;
  String? _iconBase;
  String? _status;
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> path = [""];
  late DownloadManager _dm;

  void _updatePath(List<String> newPath) {
    setState(() {
      path = newPath;
    });
  }

  String? _icon(int size) {
    if (_iconBase == null) return null;
    return '$_iconBase/$size';
  }

  String _logo() {
    return "${widget.client.baseURL.origin}/index.php/apps/theming/image/logoheader";
  }

  void _fetchData() async {
    try {
      final user = (await widget.client.provisioningApi.users.getCurrentUser())
          .body
          .ocs
          .data;
      final userStatus =
          (await widget.client.userStatus.userStatus.getStatus()).body.ocs.data;

      setState(() {
        _user = user;
        _iconBase =
            "${widget.client.baseURL.origin}/index.php/avatar/${user.id}";
        _status = userStatus.status.toString();
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch data: $e';
        _isLoading = false;
      });
    }
  }

  void _onBatchUpdate(List<DownloadItem> items) {
    if (mounted) {
      setState(() {
        // trigger UI update
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getStringPref("dm").then((dmJson) {
      if (dmJson != null) {
        try {
          final decodedJson = jsonDecode(dmJson);
          print("Loading DownloadManager state: $decodedJson");
          _dm = DownloadManager.fromJson(
            decodedJson,
            onBatchUpdate: _onBatchUpdate,
          );
        } catch (e) {
          print("Failed to load DownloadManager state: $e");
        }
      }
    });
    _dm = DownloadManager(onBatchUpdate: _onBatchUpdate);
    _fetchData();
  }

  @override
  void dispose() {
    _dm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: Colors.transparent,
        title: CachedNetworkImage(
          imageUrl: _logo(),
          httpHeaders: {"user-agent": USER_AGENT},
          errorWidget: (context, url, error) {
            return Text(
              "Nextcloud Client",
              style: const TextStyle(fontWeight: .w600),
            );
          },
        ),
        actionsPadding: EdgeInsets.only(right: 10),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: _iconBase == null
                    ? Icon(Icons.account_circle)
                    : SizedBox(
                        width: 32,
                        height: 32,
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(_icon(64)!),
                        ),
                      ),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
          SizedBox(width: 5),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchData();
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : _errorMessage.isNotEmpty
            ? Text(_errorMessage)
            : SizedBox(
                width: .maxFinite,
                height: .maxFinite,
                child: FileTabs(
                  client: widget.client,
                  davClient: widget.davClient,
                  path: path,
                  updatePath: _updatePath,
                  dm: _dm,
                ),
              ),
      ),
      endDrawer: Drawer(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Flex(
            direction: .vertical,
            children: [
              UserAccountDisplay(
                displayName: _user?.displayName,
                status: _status,
                icon: _icon(512),
                email: _user?.email,
                logout: widget.logout,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: .end,
                  children: [Text(widget.client.baseURL.host)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
