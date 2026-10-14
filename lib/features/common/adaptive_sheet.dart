import 'package:flutter/material.dart';

/// Width from which a sheet becomes a centred dialog.
const wideSheetBreakpoint = 700.0;

/// A bottom sheet on phones, a centred dialog on wide screens (desktop
/// browsers), where a full-width sheet looks stretched.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (MediaQuery.sizeOf(context).width >= wideSheetBreakpoint) {
    return showDialog<T>(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: builder,
  );
}
