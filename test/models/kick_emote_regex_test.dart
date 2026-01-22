import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kick emote regex pattern matching', () {
    // Current regex used in code for matching single emote tokens
    final emoteRegex = RegExp(r'^\[emote:(\d+):([^\]]+)\]$');

    var word = '[emote:3703808:fato000atlasirtima]';
    var match = emoteRegex.firstMatch(word);

    expect(match, isNotNull);
    expect(match?.group(1), '3703808');
    expect(match?.group(2), 'fato000atlasirtima');

    // Should not match plain text
    word = 'plainText';
    match = emoteRegex.firstMatch(word);
    expect(match, isNull);

    // Should not match partial (if checking full word match as per renderer logic)
    word = 'prefix[emote:123:name]';
    match = emoteRegex.firstMatch(word);
    expect(match, isNull);
  });
}
