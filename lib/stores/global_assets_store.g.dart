// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_assets_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$GlobalAssetsStore on GlobalAssetsStoreBase, Store {
  Computed<Map<String, Emote>>? _$globalEmoteMapComputed;

  @override
  Map<String, Emote> get globalEmoteMap =>
      (_$globalEmoteMapComputed ??= Computed<Map<String, Emote>>(
        () => super.globalEmoteMap,
        name: 'GlobalAssetsStoreBase.globalEmoteMap',
      )).value;

  late final _$_isLoadedAtom = Atom(
    name: 'GlobalAssetsStoreBase._isLoaded',
    context: context,
  );

  bool get isLoaded {
    _$_isLoadedAtom.reportRead();
    return super._isLoaded;
  }

  @override
  bool get _isLoaded => isLoaded;

  @override
  set _isLoaded(bool value) {
    _$_isLoadedAtom.reportWrite(value, super._isLoaded, () {
      super._isLoaded = value;
    });
  }

  late final _$_isLoadingAtom = Atom(
    name: 'GlobalAssetsStoreBase._isLoading',
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

  late final _$_kickGlobalEmotesAtom = Atom(
    name: 'GlobalAssetsStoreBase._kickGlobalEmotes',
    context: context,
  );

  List<Emote> get kickGlobalEmotes {
    _$_kickGlobalEmotesAtom.reportRead();
    return super._kickGlobalEmotes;
  }

  @override
  List<Emote> get _kickGlobalEmotes => kickGlobalEmotes;

  @override
  set _kickGlobalEmotes(List<Emote> value) {
    _$_kickGlobalEmotesAtom.reportWrite(value, super._kickGlobalEmotes, () {
      super._kickGlobalEmotes = value;
    });
  }

  late final _$_sevenTVGlobalEmotesAtom = Atom(
    name: 'GlobalAssetsStoreBase._sevenTVGlobalEmotes',
    context: context,
  );

  List<Emote> get sevenTVGlobalEmotes {
    _$_sevenTVGlobalEmotesAtom.reportRead();
    return super._sevenTVGlobalEmotes;
  }

  @override
  List<Emote> get _sevenTVGlobalEmotes => sevenTVGlobalEmotes;

  @override
  set _sevenTVGlobalEmotes(List<Emote> value) {
    _$_sevenTVGlobalEmotesAtom.reportWrite(
      value,
      super._sevenTVGlobalEmotes,
      () {
        super._sevenTVGlobalEmotes = value;
      },
    );
  }

  late final _$ensureLoadedAsyncAction = AsyncAction(
    'GlobalAssetsStoreBase.ensureLoaded',
    context: context,
  );

  @override
  Future<void> ensureLoaded({
    bool showKickEmotes = true,
    bool show7TVEmotes = true,
  }) {
    return _$ensureLoadedAsyncAction.run(
      () => super.ensureLoaded(
        showKickEmotes: showKickEmotes,
        show7TVEmotes: show7TVEmotes,
      ),
    );
  }

  late final _$refreshAsyncAction = AsyncAction(
    'GlobalAssetsStoreBase.refresh',
    context: context,
  );

  @override
  Future<void> refresh({
    bool showKickEmotes = true,
    bool show7TVEmotes = true,
  }) {
    return _$refreshAsyncAction.run(
      () => super.refresh(
        showKickEmotes: showKickEmotes,
        show7TVEmotes: show7TVEmotes,
      ),
    );
  }

  late final _$_fetchGlobalAssetsAsyncAction = AsyncAction(
    'GlobalAssetsStoreBase._fetchGlobalAssets',
    context: context,
  );

  @override
  Future<void> _fetchGlobalAssets({
    required bool showKickEmotes,
    required bool show7TVEmotes,
  }) {
    return _$_fetchGlobalAssetsAsyncAction.run(
      () => super._fetchGlobalAssets(
        showKickEmotes: showKickEmotes,
        show7TVEmotes: show7TVEmotes,
      ),
    );
  }

  @override
  String toString() {
    return '''
globalEmoteMap: ${globalEmoteMap}
    ''';
  }
}
