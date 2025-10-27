import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigate to a named route (replaces current page)
  static Future<void> navigateTo(
      String routeName, {
        Map<String, String>? pathParameters,
        Map<String, String>? queryParameters,
        Object? extra,
      }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    context.goNamed(
      routeName,
      pathParameters: pathParameters ?? {},
      queryParameters: queryParameters ?? {},
      extra: extra,
    );
  }

  /// Push a named route (adds to stack)
  static Future<void> pushTo(
      String routeName, {
        Map<String, String>? pathParameters,
        Map<String, String>? queryParameters,
        Object? extra,
      }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    context.pushNamed(
      routeName,
      pathParameters: pathParameters ?? {},
      queryParameters: queryParameters ?? {},
      extra: extra,
    );
  }

  /// Pop the current route if possible
  static void pop<T extends Object?>([T? result]) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    } else {
      // No route to pop
    }
  }

  /// Safer pop that doesn't throw if at root
  static void safePop() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (context.canPop()) {
      context.pop();
    } else {
      // Optional: navigate to a fallback screen
      // context.goNamed('home');
    }
  }

  /// Pop until a named route is found in the stack
  static void popUntil(String routeName) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Navigator.of(context).popUntil((route) => route.settings.name == routeName);
  }

  /// Replace current route
  static Future<void> replaceWith(
      String routeName, {
        Map<String, String>? pathParameters,
        Object? extra,
      }) async {
    await navigateTo(routeName, pathParameters: pathParameters, extra: extra);
  }
}
