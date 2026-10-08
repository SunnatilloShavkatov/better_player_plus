// Flutter imports:
import 'package:material_ui/material_ui.dart';

class BetterPlayerMaterialClickableWidget extends StatelessWidget {
  const new({super.key, required this.onTap, required this.child});
  final Widget child;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) => Material(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
    clipBehavior: Clip.hardEdge,
    color: Colors.transparent,
    child: InkWell(onTap: onTap, child: child),
  );
}
