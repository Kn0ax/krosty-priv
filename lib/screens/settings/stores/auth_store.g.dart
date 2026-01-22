// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AuthStore on AuthBase, Store {
  Computed<Map<String, String>>? _$headersKickComputed;

  @override
  Map<String, String> get headersKick =>
      (_$headersKickComputed ??= Computed<Map<String, String>>(
        () => super.headersKick,
        name: 'AuthBase.headersKick',
      )).value;

  late final _$_xsrfTokenAtom = Atom(
    name: 'AuthBase._xsrfToken',
    context: context,
  );

  String? get xsrfToken {
    _$_xsrfTokenAtom.reportRead();
    return super._xsrfToken;
  }

  @override
  String? get _xsrfToken => xsrfToken;

  @override
  set _xsrfToken(String? value) {
    _$_xsrfTokenAtom.reportWrite(value, super._xsrfToken, () {
      super._xsrfToken = value;
    });
  }

  late final _$_sessionTokenAtom = Atom(
    name: 'AuthBase._sessionToken',
    context: context,
  );

  String? get sessionToken {
    _$_sessionTokenAtom.reportRead();
    return super._sessionToken;
  }

  @override
  String? get _sessionToken => sessionToken;

  @override
  set _sessionToken(String? value) {
    _$_sessionTokenAtom.reportWrite(value, super._sessionToken, () {
      super._sessionToken = value;
    });
  }

  late final _$_isLoggedInAtom = Atom(
    name: 'AuthBase._isLoggedIn',
    context: context,
  );

  bool get isLoggedIn {
    _$_isLoggedInAtom.reportRead();
    return super._isLoggedIn;
  }

  @override
  bool get _isLoggedIn => isLoggedIn;

  @override
  set _isLoggedIn(bool value) {
    _$_isLoggedInAtom.reportWrite(value, super._isLoggedIn, () {
      super._isLoggedIn = value;
    });
  }

  late final _$_connectionStateAtom = Atom(
    name: 'AuthBase._connectionState',
    context: context,
  );

  ConnectionState get connectionState {
    _$_connectionStateAtom.reportRead();
    return super._connectionState;
  }

  @override
  ConnectionState get _connectionState => connectionState;

  @override
  set _connectionState(ConnectionState value) {
    _$_connectionStateAtom.reportWrite(value, super._connectionState, () {
      super._connectionState = value;
    });
  }

  late final _$_errorAtom = Atom(name: 'AuthBase._error', context: context);

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

  late final _$initAsyncAction = AsyncAction('AuthBase.init', context: context);

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loginWithTokensAsyncAction = AsyncAction(
    'AuthBase.loginWithTokens',
    context: context,
  );

  @override
  Future<void> loginWithTokens({
    required String xsrfToken,
    required String sessionToken,
  }) {
    return _$loginWithTokensAsyncAction.run(
      () => super.loginWithTokens(
        xsrfToken: xsrfToken,
        sessionToken: sessionToken,
      ),
    );
  }

  late final _$logoutAsyncAction = AsyncAction(
    'AuthBase.logout',
    context: context,
  );

  @override
  Future<void> logout() {
    return _$logoutAsyncAction.run(() => super.logout());
  }

  late final _$handleUnauthorizedAsyncAction = AsyncAction(
    'AuthBase.handleUnauthorized',
    context: context,
  );

  @override
  Future<void> handleUnauthorized() {
    return _$handleUnauthorizedAsyncAction.run(
      () => super.handleUnauthorized(),
    );
  }

  @override
  String toString() {
    return '''
headersKick: ${headersKick}
    ''';
  }
}
