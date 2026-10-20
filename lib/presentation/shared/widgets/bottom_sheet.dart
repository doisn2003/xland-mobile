import 'package:flutter/material.dart';

/// Protect every sheet's controls from system navigation bars, including
/// side navigation/cutouts in landscape. Builder context consumes the safe
/// padding and keyboard insets once, so nested forms cannot double-count them.
Future<T?> showXLandBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  bool? showDragHandle,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  backgroundColor: backgroundColor,
  showDragHandle: showDragHandle,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(top: false, child: Builder(builder: builder)),
    ),
  ),
);
