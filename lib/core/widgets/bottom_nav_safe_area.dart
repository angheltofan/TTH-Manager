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
    this.insetLift = 8,
  });

  final Widget child;
  final Color backgroundColor;

  /// Extra space added between the bar's content row and the bottom
  /// system inset (iPhone Home Indicator or Android gesture-nav pill).
  /// Applied ONLY when `viewPadding.bottom > 0`.
  ///
  /// Without this, the icon + label row sits flush against the inset
  /// zone — visually cramped on iPhones with onlyShowSelected labels.
  /// 8 dp of lift matches the spacing iOS Mail / WhatsApp / Telegram
  /// use above the indicator and gives the active item's label real
  /// breathing room. On platforms without a bottom inset the lift
  /// collapses to 0 so Android 3-button-nav / desktop / iPad are
  /// unchanged.
  final double insetLift;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Only lift on devices that actually have a bottom inset. Adding
    // the lift unconditionally would shrink the usable scaffold body
    // for the (rare) hosts that have no inset at all.
    final lift = bottomInset > 0 ? insetLift : 0.0;
    return Material(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + lift),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      ),
    );
  }
}
