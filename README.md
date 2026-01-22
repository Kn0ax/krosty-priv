![Showcase of the Krosty app with screenshots in a masonry grid](https://github.com/kn0ax/krosty/assets/54859075/09178dcc-2fd2-4618-8076-502719159424)

This project is forked from [Frosty by Tommy Chow](https://github.com/tommyxchow/frosty). Without his work, this project would not really exist.
<p>
  <a href="https://github.com/kn0ax/krosty/actions/workflows/ci.yml">
    <img
      alt="Badge showing the CI status."
      src="https://github.com/kn0ax/krosty/actions/workflows/ci.yml/badge.svg"
    />
  </a>
  <a href="https://github.com/kn0ax/krosty/issues">
    <img
      alt="Badge showing the number of open issues."
      src="https://img.shields.io/github/issues/kn0ax/krosty"
    />
  </a>
  <a href="https://github.com/kn0ax/krosty/commits">
    <img
      alt="Badge showing the date of the last commit."
      src="https://img.shields.io/github/last-commit/kn0ax/krosty"
    />
  </a>
  <a href="https://github.com/kn0ax/krosty/blob/main/LICENSE">
    <img
      alt="Badge showing the current license of the repo."
      src="https://img.shields.io/github/license/kn0ax/krosty"
    />
  </a>
  <a href="https://github.com/kn0ax/krosty/releases/latest">
    <img
      alt="Badge showing the version of the latest release."
      src="https://img.shields.io/github/v/release/kn0ax/krosty"
    />
  </a>
</p>

## Download

TODO 

## Why

The official Kick mobile app on Android sucks. It crashes constantly and and not stable at all. It also doesn't support emotes from [7TV](https://chrome.google.com/webstore/detail/7tv/ammjkodgmmoknidbanneddgankgfejfh), third-party extensions used by millions. As a result, only emote text names are rendered rather than their actual image or GIF, making the chat unreadable in many channels.

## Features

- Support for 7TV emotes and badges
- Browse followed streams, top streams, and top categories
- Autocomplete for emotes and user mentions
- Light, dark, and black (OLED) themes
- Search for channels and categories
- See and filter chatters in a channel
- Local chat user message history
- Theater and fullscreen mode
- Watch live streams with chat
- Picture-in-picture mode
- Block and report users
- Emote menu
- Sleep timer
- And more...

For a more detailed overview, visit [krosty.kn0.dev](https://krosty.kn0.dev).

## Development setup

1. [Install Flutter](https://docs.flutter.dev/get-started/install).

2. Clone this repo.

3. Go to the Kick developer portal and register a new application to retrieve a **Client ID** and **Client Secret**.

4. Use [`--dart-define`](https://dartcode.org/docs/using-dart-define-in-flutter/) to set the `clientId` and `secret` environment variables with your **Client ID** and **Client Secret**.

5. Run `flutter pub get` to fetch all the dependencies.

6. Choose an emulator or device and run the app!

> [!IMPORTANT]
> Krosty uses [MobX](https://mobx.netlify.app/) for state management. Please refer to the documentation about code generation, otherwise your changes within MobX stores may not be applied.
## Donate

If you appreciate this project and would like to donate/tip, you can to original author or me:

- [GitHub Sponsors of Tommy](https://github.com/sponsors/tommyxchow)
- [Buy Me a Coffee of Tommy](https://www.buymeacoffee.com/tommychow)

- [GitHub Sponsors of kn0ax](https://github.com/sponsors/kn0ax)


Otherwise, downloading Frosty/Krosty, leaving a review, or starring this repository is more than enough to show support. Thank you!
## License

Krosty is licensed under [AGPL-3.0-or-later](LICENSE).

This project is forked from [Frosty by Tommy Chow](https://github.com/tommyxchow/frosty).
