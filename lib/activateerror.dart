import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';

void activateError(BuildContext context, String message) {
  showToast(
    message, // Используем переданное сообщение
    context: context,
    animation: StyledToastAnimation.slideFromBottomFade,
    position: StyledToastPosition.center,
    duration: const Duration(seconds: 2),
    backgroundColor: Colors.grey,
    textStyle: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white),
    curve: Curves.elasticOut,
    reverseCurve: Curves.linear,
  );
}
