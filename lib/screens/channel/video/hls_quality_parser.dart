import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Represents a quality variant from an HLS master playlist.
class HlsVariant {
  /// The full URL to the variant's playlist.
  final String url;

  /// Bandwidth in bits per second.
  final int bandwidth;

  /// Video width in pixels (null if not specified).
  final int? width;

  /// Video height in pixels (null if not specified).
  final int? height;

  /// Frame rate (null if not specified).
  final double? frameRate;

  /// Video codec (e.g., "avc1.64002A").
  final String? codecs;

  /// User-friendly label (e.g., "1080p60", "720p30").
  final String label;

  const HlsVariant({
    required this.url,
    required this.bandwidth,
    this.width,
    this.height,
    this.frameRate,
    this.codecs,
    required this.label,
  });

  @override
  String toString() => 'HlsVariant($label, ${bandwidth ~/ 1000}kbps)';
}

/// Parses HLS master playlists to extract available quality variants.
class HlsQualityParser {
  static final _dio = Dio();

  /// Parse an HLS master playlist and return available quality variants.
  ///
  /// The variants are sorted by bandwidth in descending order (highest first).
  static Future<List<HlsVariant>> parsePlaylist(String masterUrl) async {
    try {
      final response = await _dio.get<String>(
        masterUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.data == null) {
        debugPrint('HLS parser: Empty response from master playlist');
        return [];
      }

      return _parseM3u8Content(response.data!, masterUrl);
    } catch (e) {
      debugPrint('HLS parser: Failed to fetch master playlist: $e');
      return [];
    }
  }

  /// Parse the m3u8 content and extract variants.
  static List<HlsVariant> _parseM3u8Content(String content, String masterUrl) {
    final lines = content.split('\n');
    final variants = <HlsVariant>[];

    // Check if this is a valid HLS playlist
    if (lines.isEmpty || !lines.first.trim().startsWith('#EXTM3U')) {
      debugPrint('HLS parser: Invalid m3u8 playlist');
      return [];
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Look for stream info tags
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attributes = _parseAttributes(line);

        // Get the variant URL from the next line
        String? variantUrl;
        for (var j = i + 1; j < lines.length; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
            variantUrl = nextLine;
            break;
          }
        }

        if (variantUrl == null) continue;

        // Resolve relative URLs
        final resolvedUrl = _resolveUrl(masterUrl, variantUrl);

        // Parse attributes
        final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0;
        final resolution = attributes['RESOLUTION'];
        final frameRateStr = attributes['FRAME-RATE'];
        final codecs = attributes['CODECS'];

        int? width;
        int? height;
        if (resolution != null && resolution.contains('x')) {
          final parts = resolution.split('x');
          width = int.tryParse(parts[0]);
          height = int.tryParse(parts[1]);
        }

        final frameRate = double.tryParse(frameRateStr ?? '');

        // Generate user-friendly label
        final label = _generateLabel(height, frameRate, attributes['NAME']);

        variants.add(HlsVariant(
          url: resolvedUrl,
          bandwidth: bandwidth,
          width: width,
          height: height,
          frameRate: frameRate,
          codecs: codecs,
          label: label,
        ));
      }
    }

    // Sort by bandwidth descending (highest quality first)
    variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));

    return variants;
  }

  /// Parse attributes from an EXT-X-STREAM-INF line.
  static Map<String, String> _parseAttributes(String line) {
    final attributes = <String, String>{};

    // Remove the tag prefix
    final attrString = line.replaceFirst('#EXT-X-STREAM-INF:', '');

    // Parse key=value pairs, handling quoted values
    final regex = RegExp(r'([A-Z-]+)=(?:"([^"]*)"|([^,]*))');
    for (final match in regex.allMatches(attrString)) {
      final key = match.group(1)!;
      final value = match.group(2) ?? match.group(3) ?? '';
      attributes[key] = value;
    }

    return attributes;
  }

  /// Resolve a potentially relative URL against the master playlist URL.
  static String _resolveUrl(String masterUrl, String variantUrl) {
    // If already absolute, return as-is
    if (variantUrl.startsWith('http://') || variantUrl.startsWith('https://')) {
      return variantUrl;
    }

    // Get the base URL (everything up to the last /)
    final lastSlash = masterUrl.lastIndexOf('/');
    if (lastSlash == -1) return variantUrl;

    final baseUrl = masterUrl.substring(0, lastSlash + 1);
    return '$baseUrl$variantUrl';
  }

  /// Generate a user-friendly label from resolution and frame rate.
  static String _generateLabel(int? height, double? frameRate, String? name) {
    // If we have a name from the playlist, use it if it looks like a quality label
    if (name != null && name.isNotEmpty) {
      // Common patterns: "1080p60", "720p", "Source", etc.
      if (RegExp(r'^\d+p').hasMatch(name) || name.toLowerCase() == 'source') {
        return name;
      }
    }

    if (height == null) return 'Unknown';

    // Round frame rate for display
    final fps = frameRate?.round() ?? 30;

    // Only show fps if > 30
    if (fps > 30) {
      return '${height}p$fps';
    }
    return '${height}p';
  }
}
