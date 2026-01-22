import 'package:flutter/material.dart';

/// Kick API client ID (from Kick Developer Portal).
//const kickClientId = String.fromEnvironment('KICK_CLIENT_ID');

/// Kick API client secret.
// const kickClientSecret = String.fromEnvironment('KICK_CLIENT_SECRET');

/// OAuth redirect URI for the app.
// const kickRedirectUri = 'krosty://auth/callback';

/// Kick Pusher WebSocket configuration.
const kickPusherAppKey = '32cbd69e4b950bf97679';
const kickPusherCluster = 'us2';
const kickPusherWsUrl =
    'wss://ws-$kickPusherCluster.pusher.com/app/$kickPusherAppKey'
    '?protocol=7&client=js&version=8.4.0-rc2&flash=false';

/// 7TV emotes with zero width to allow for overlaying other emotes.
const zeroWidthEmotes = [
  'SoSnowy',
  'IceCold',
  'SantaHat',
  'TopHat',
  'ReinDeer',
  'CandyCane',
  'cvMask',
  'cvHazmat',
];

/// Regex for matching strings that contain lower or upper case English characters.
final regexEnglish = RegExp(r'[a-zA-Z]');

/// Regex for matching strings that contain only numeric characters.
final regexNumbersOnly = RegExp(r'^\d+$');

/// Regex for matching URLs and file names in text.
final regexLink = RegExp(
  r'(?<![A-Za-z0-9_.-])' // left boundary
  r'(?:' // ───────── URL ─────────
  r'(?:www\.)?' // optional www.
  r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
  r'[A-Za-z]{2,63}' // TLD
  r'(?::\d{1,5})?' // optional :port
  r'(?:/[^\s]*)?' // optional path / query / hash
  r'|' // ───── file names ──────
  r'[A-Za-z0-9_-]+\.(?:' // bare `doom.exe`, `logo.png`, …
  r'exe|png|jpe?g|gif|bmp|webp|mp4|avi|zip|rar|pdf'
  r')'
  r')'
  r'(?![A-Za-z0-9-])', // right boundary
  caseSensitive: false,
);

/// The default badge width and height.
const defaultBadgeSize = 18.0;

/// The default emote width and height when none are provided.
const defaultEmoteSize = 28.0;

/// Default chat colors for users without a custom color.
/// Kick uses hex colors directly from the API, but we provide fallbacks.
const defaultChatColors = [
  Color(0xFF53FC18), // Kick green
  Color(0xFFFF69B4), // Hot pink
  Color(0xFF1E90FF), // Dodger blue
  Color(0xFFFF4500), // Orange red
  Color(0xFF9ACD32), // Yellow green
  Color(0xFFFF6347), // Tomato
  Color(0xFF00CED1), // Dark turquoise
  Color(0xFFDA70D6), // Orchid
];

/// Kick brand color (green).
const kickBrandColor = Color(0xFF53FC18);

/// Parse a hex color string to Color.
Color parseHexColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) {
    // Return a random default color based on hash
    return defaultChatColors[hexColor.hashCode % defaultChatColors.length];
  }

  // Remove # if present
  String hex = hexColor.replaceFirst('#', '');

  // Add alpha if not present
  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  return Color(int.parse(hex, radix: 16));
}
