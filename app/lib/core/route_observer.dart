import 'package:flutter/widgets.dart';

/// Registered on MaterialApp so screens beneath a pushed route (e.g. the
/// feed, sitting under Record -> Ride Summary) can refresh themselves when
/// that pushed route is popped and they become visible again.
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();
