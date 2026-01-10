import 'package:flutter/material.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:provider/provider.dart';

class ProfilePicture extends StatefulWidget {
  final String userLogin;
  final String? profileUrl;
  final double radius;

  const ProfilePicture({
    super.key,
    required this.userLogin,
    this.profileUrl,
    this.radius = 20,
  });

  @override
  State<ProfilePicture> createState() => _ProfilePictureState();
}

class _ProfilePictureState extends State<ProfilePicture> {
  // Cache profile image URLs to avoid repeated API calls
  static final Map<String, String> _urlCache = {};
  static final Map<String, Future<String>> _pendingRequests = {};

  @override
  void initState() {
    super.initState();
  }

  static const _defaultProfilePic =
      'https://files.kick.com/images/profile_image/default2.jpeg';

  Future<String> _getProfileImageUrl() async {
    // Return provided URL if available (avoid API call)
    if (widget.profileUrl?.isNotEmpty == true) {
      return widget.profileUrl!;
    }

    final userLogin = widget.userLogin;

    // Return cached URL if available
    if (_urlCache.containsKey(userLogin)) {
      return _urlCache[userLogin]!;
    }

    // Return existing pending request if one is already in progress
    if (_pendingRequests.containsKey(userLogin)) {
      return _pendingRequests[userLogin]!;
    }

    // Make new request and cache it
    final future = context
        .read<KickApi>()
        .getUser(username: userLogin)
        .then(
          (user) => user.profilePic?.isNotEmpty == true
              ? user.profilePic!
              : _defaultProfilePic,
        );
    _pendingRequests[userLogin] = future;

    try {
      final url = await future;
      _urlCache[userLogin] = url;
      _pendingRequests.remove(userLogin);
      return url;
    } catch (e) {
      _pendingRequests.remove(userLogin);
      // Return default on error
      return _defaultProfilePic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainer;

    return ClipOval(
      child: FutureBuilder<String>(
        future: _getProfileImageUrl(),
        builder: (context, snapshot) {
          return snapshot.hasData
              ? FrostyCachedNetworkImage(
                  width: diameter,
                  height: diameter,
                  imageUrl: snapshot.data!,
                  placeholder: (context, url) =>
                      ColoredBox(color: placeholderColor),
                )
              : Container(
                  color: placeholderColor,
                  width: diameter,
                  height: diameter,
                );
        },
      ),
    );
  }
}
