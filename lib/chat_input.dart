import 'package:didactic_waddle/message.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

typedef OnMessageCallback = void Function(MessagePayload);

class ChatInput extends StatefulWidget {
  final OnMessageCallback _on_message;

  const ChatInput({super.key, required OnMessageCallback on_message})
    : _on_message = on_message;
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _text_controller = TextEditingController();
  final _text_field_key = GlobalKey();
  double _real_text_field_height = 0;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox =
          _text_field_key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        if (_real_text_field_height != height) {
          setState(() {
            _real_text_field_height = height;
          });
        }
      }
    });
    return FTextField(
      key: _text_field_key,
      keyboardType: TextInputType.text,
      minLines: 1,
      maxLines: 10,
      maxLength: 1024,
      hint: "Write message for all...",
      autofocus: true,
      controller: _text_controller,
      textAlignVertical: TextAlignVertical.bottom,
      onSubmit: (_) => _process_text_message(),
      suffixBuilder:
          (
            BuildContext context,
            FTextFieldStyle style,
            Set<WidgetState> states,
          ) {
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: _real_text_field_height),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FButton.icon(
                        onPress: _process_file_message,
                        style: FButtonStyle.ghost(),
                        child: Icon(Icons.attach_file),
                      ),
                      FButton.icon(
                        onPress: _process_text_message,
                        style: FButtonStyle.ghost(),
                        child: Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
    );
  }

  Future<void> _process_text_message() async {
    if (_text_controller.text.isEmpty) {
      return;
    }
    widget._on_message(TextMessage(_text_controller.text));
    _text_controller.clear();
  }

  Future<void> _process_file_message() async {
    //
  }
}
