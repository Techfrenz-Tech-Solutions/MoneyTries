import 'package:flutter/material.dart';

/// App-wide [RouteObserver], registered as a `navigatorObservers` entry on
/// the app's `MaterialApp` (see `main.dart`). Screens that need to know when
/// they become visible again — e.g. after popping back from a sub-screen —
/// subscribe to this with `routeObserver.subscribe(this, route)` and mix in
/// `RouteAware`, overriding `didPopNext()` to re-fetch fresh data.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();