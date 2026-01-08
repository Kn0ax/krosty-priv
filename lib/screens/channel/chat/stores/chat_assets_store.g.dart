// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_assets_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChatAssetsStore on ChatAssetsStoreBase, Store {
  Computed<Map<String, Emote>>? _$emotesComputed;

  @override
  Map<String, Emote> get emotes =>
      (_$emotesComputed ??= Computed<Map<String, Emote>>(
        () => super.emotes,
        name: 'ChatAssetsStoreBase.emotes',
      )).value;

  late final _$_channelEmotesAtom = Atom(
    name: 'ChatAssetsStoreBase._channelEmotes',
    context: context,
  );

  ObservableMap<String, Emote> get channelEmotes {
    _$_channelEmotesAtom.reportRead();
    return super._channelEmotes;
  }

  @override
  ObservableMap<String, Emote> get _channelEmotes => channelEmotes;

  @override
  set _channelEmotes(ObservableMap<String, Emote> value) {
    _$_channelEmotesAtom.reportWrite(value, super._channelEmotes, () {
      super._channelEmotes = value;
    });
  }

  late final _$_isLoadingAtom = Atom(
    name: 'ChatAssetsStoreBase._isLoading',
    context: context,
  );

  bool get isLoading {
    _$_isLoadingAtom.reportRead();
    return super._isLoading;
  }

  @override
  bool get _isLoading => isLoading;

  @override
  set _isLoading(bool value) {
    _$_isLoadingAtom.reportWrite(value, super._isLoading, () {
      super._isLoading = value;
    });
  }

  late final _$_errorAtom = Atom(
    name: 'ChatAssetsStoreBase._error',
    context: context,
  );

  String? get error {
    _$_errorAtom.reportRead();
    return super._error;
  }

  @override
  String? get _error => error;

  @override
  set _error(String? value) {
    _$_errorAtom.reportWrite(value, super._error, () {
      super._error = value;
    });
  }

  late final _$showEmoteMenuAtom = Atom(
    name: 'ChatAssetsStoreBase.showEmoteMenu',
    context: context,
  );

  @override
  bool get showEmoteMenu {
    _$showEmoteMenuAtom.reportRead();
    return super.showEmoteMenu;
  }

  @override
  set showEmoteMenu(bool value) {
    _$showEmoteMenuAtom.reportWrite(value, super.showEmoteMenu, () {
      super.showEmoteMenu = value;
    });
  }

  late final _$fetchAssetsAsyncAction = AsyncAction(
    'ChatAssetsStoreBase.fetchAssets',
    context: context,
  );

  @override
  Future<void> fetchAssets({
    bool showKickEmotes = true,
    bool show7TVEmotes = true,
  }) {
    return _$fetchAssetsAsyncAction.run(
      () => super.fetchAssets(
        showKickEmotes: showKickEmotes,
        show7TVEmotes: show7TVEmotes,
      ),
    );
  }

  @override
  String toString() {
    return '''
showEmoteMenu: ${showEmoteMenu},
emotes: ${emotes}
    ''';
  }
}
