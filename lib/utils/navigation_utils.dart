import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void safeNavigateBack(BuildContext context, {String fallbackRoute = '/'}) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }

  router.go(fallbackRoute);
}

void safePopWithResult<T>(
  BuildContext context,
  T result, {
  String fallbackRoute = '/',
}) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop(result);
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop(result);
    return;
  }

  router.go(fallbackRoute);
}
