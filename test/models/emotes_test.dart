import 'package:flutter_test/flutter_test.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/apis/kick_api.dart';

void main() {
  group('Emote.fromKick', () {
    test('creates emote with correct URL', () {
      final kickEmote = const KickEmoteData(id: 123, name: 'test_emote');

      final emote = Emote.fromKick(kickEmote, EmoteType.kickChannel);

      expect(emote.url, 'https://files.kick.com/emotes/123/fullsize');
      expect(emote.name, 'test_emote');
      expect(emote.type, EmoteType.kickChannel);
      expect(emote.zeroWidth, isFalse);
    });
  });

  group('Emote.from7TV', () {
    test('creates emote with WEBP URL (filters AVIF)', () {
      final emote7TV = Emote7TV(
        '60afbb7f566c3e1fc9af3a48',
        'emote_name',
        Emote7TVData(
          '60afbb7f566c3e1fc9af3a48',
          'emote_name',
          0, // No flags
          const Owner7TV(username: 'owner', displayName: 'Owner'),
          Emote7TVHost('//cdn.7tv.app/emote/60afbb7f566c3e1fc9af3a48', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
            Emote7TVFile('2x.webp', 64, 64, 'WEBP'),
            Emote7TVFile('3x.webp', 96, 96, 'WEBP'),
            Emote7TVFile('4x.webp', 128, 128, 'WEBP'),
            Emote7TVFile('1x.avif', 32, 32, 'AVIF'),
            Emote7TVFile('2x.avif', 64, 64, 'AVIF'),
            Emote7TVFile('3x.avif', 96, 96, 'AVIF'),
            Emote7TVFile('4x.avif', 128, 128, 'AVIF'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVChannel);

      // Should use WEBP, not AVIF
      expect(emote.url, contains('webp'));
      expect(emote.url, isNot(contains('avif')));
      expect(
        emote.url,
        'https://cdn.7tv.app/emote/60afbb7f566c3e1fc9af3a48/4x.webp',
      );
    });

    test('detects zero-width from flag bit 8 (256)', () {
      final emote7TV = Emote7TV(
        'zw123',
        'ZeroWidth',
        Emote7TVData(
          'zw123',
          'ZeroWidth',
          256, // Bit 8 set = zero-width
          null,
          Emote7TVHost('//cdn.7tv.app/emote/zw123', [
            Emote7TVFile('1x.webp', 32, 32, 'WEBP'),
          ]),
        ),
      );

      final emote = Emote.from7TV(emote7TV, EmoteType.sevenTVGlobal);

      expect(emote.zeroWidth, isTrue);
    });
  });

  group('EmoteType', () {
    test('toString returns human-readable string', () {
      expect(EmoteType.kickGlobal.toString(), 'Kick global emote');
      expect(EmoteType.kickChannel.toString(), 'Kick channel emote');
      expect(EmoteType.sevenTVGlobal.toString(), '7TV global emote');
      expect(EmoteType.sevenTVChannel.toString(), '7TV channel emote');
    });
  });
}
