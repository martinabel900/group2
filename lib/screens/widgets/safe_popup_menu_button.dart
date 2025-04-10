import 'package:flutter/material.dart';

class SafePopupMenuButton<T> extends StatefulWidget {
  final Widget icon;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T> onSelected;

  const SafePopupMenuButton({
    Key? key,
    required this.icon,
    required this.itemBuilder,
    required this.onSelected,
  }) : super(key: key);

  @override
  _SafePopupMenuButtonState<T> createState() => _SafePopupMenuButtonState<T>();
}

class _SafePopupMenuButtonState<T> extends State<SafePopupMenuButton<T>> {
  final GlobalKey _buttonKey = GlobalKey();

  void _showSafeMenu() async {
    final RenderBox? buttonBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;
    final Offset buttonPosition = buttonBox.localToGlobal(Offset.zero);
    final Size buttonSize = buttonBox.size;
    final OverlayState? overlay = Overlay.of(context);
    if (overlay == null) return;
    
    final result = await showMenu<T>(
      context: overlay.context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height,
        buttonPosition.dx + buttonSize.width,
        buttonPosition.dy,
      ),
      items: widget.itemBuilder(context),
    );
    if (result != null) {
      widget.onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _buttonKey,
      icon: widget.icon,
      onPressed: _showSafeMenu,
    );
  }
}