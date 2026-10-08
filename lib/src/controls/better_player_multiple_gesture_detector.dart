import 'package:material_ui/material_ui.dart';

///Helper class for GestureDetector used within Better Player. Used to pass
///gestures to upper GestureDetectors.
class BetterPlayerMultipleGestureDetector extends InheritedWidget {
  const new({
    super.key,
    required super.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });
  final void Function()? onTap;
  final void Function()? onDoubleTap;
  final void Function()? onLongPress;

  static BetterPlayerMultipleGestureDetector? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BetterPlayerMultipleGestureDetector>();

  @override
  bool updateShouldNotify(BetterPlayerMultipleGestureDetector oldWidget) => false;
}
