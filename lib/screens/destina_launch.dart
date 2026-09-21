import 'package:destiny/screens/destina_screen.dart';
import 'package:flutter/material.dart';

Future<void> openDestinaChat(
  BuildContext context, {
  String? seedPrompt,
  Map<String, dynamic>? seedContext,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DestinaScreen(
        seedPrompt: seedPrompt,
        seedContext: seedContext,
      ),
    ),
  );
}
