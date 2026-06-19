import 'package:flutter/material.dart';

/// Wraps a [NavigationBar] (or any bottom-nav-like child) so its visible
/// content area stays at the requested height while the colored
/// background extends downward into the bottom system inset — the
/// iPhone Home Indicator area, or the Android gesture-nav bar.
///
/// This is the spacing pattern used by WhatsApp, Telegram and
/// Instagram on iOS: a constant tab-bar row with the surface colour
/// flowing behind the home indicator, so the bar never appears to
/// "sit on top of" the gesture area.
///
/// Implementation notes:
///   • Uses [MediaQuery.viewPaddingOf] — NOT [MediaQuery.paddingOf] —
///     so the inset stays stable when the soft keyboard is up (the
///     keyboard shrinks `padding` to 0 but leaves `viewPadding`
///     untouched). The bar never collapses upward as the keyboard
///     animates in.
///   • Wraps the child in [MediaQuery.removePadding] (removeBottom)
///     because Flutter's [NavigationBar] internally already does
///     `SafeArea(top: false)`. If we did not strip the inset here, the
///     bar would pad the bottom *twice* and float far above the
///     indicator.
///   • [backgroundColor] is painted by an outer [Material] that spans
///     the full extended height. Pass the same colour the
///     [NavigationBar] itself paints (the M3 default is
///     `colorScheme.surfaceContainer`) so the inset zone is visually
///     continuous with the bar above it.
///
/// On platforms with no bottom system inset (most Androids in 3-button
/// mode, iPad, desktop, web on non-mobile browsers) `viewPadding.bottom`
/// is 0, the extra padding collapses, and the bar renders exactly as
/// before — no behaviour change.
class BottomNavSafeArea extends StatelessWidget {
  const BottomNavSafeArea({
    super.key,
    required this.child,
    required this.backgroundColor,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      ),
    );
  }
}
