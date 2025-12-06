import 'package:flutter/material.dart';
import 'package:forui/widgets/text_field.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MessageHeader {
  String user_id;
  DateTime timestamp;
  String type;

  MessageHeader({
    required this.user_id,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  static MessageHeader fromJson(Json json) {
    return MessageHeader(
      user_id: json["user_id"],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json["timestamp"] * 1000),
      type: json["type"],
    );
  }

  Json toJson() {
    return {
      "user_id": user_id,
      "timestamp": timestamp.millisecondsSinceEpoch ~/ 1000,
      "type": type,
    };
  }
}

abstract class MessagePayload {
  Json toJson();
  Widget widget(BuildContext context);
  String get type;

  static Widget throw_no_widget() {
    throw Exception(
      "You can't use this message to display. Only for internal usage",
    );
  }
}

typedef Json = Map<String, dynamic>;

final Map<String, MessagePayload Function(Json)> message_factory = {
  "text": (Json json) => TextMessage.fromJson(json),
  "file": (Json json) => FileMessage.fromJson(json),
  "hello": (Json json) => HelloMessage.fromJson(json),
};

class Message {
  MessageHeader header;
  MessagePayload payload;

  Message({required this.header, required this.payload});

  static Message fromJson(Json json, Box config) {
    final header = MessageHeader.fromJson(json["header"]);
    return Message(
      header: header,
      payload: message_factory[header.type]!(json["payload"]),
    );
  }

  Json toJson() {
    return {"header": header.toJson(), "payload": payload.toJson()};
  }
}

class TextMessage extends MessagePayload {
  String content;

  TextMessage(this.content);

  @override
  String get type => "text";
  static String get stype => "text";

  @override
  Widget widget(BuildContext context) {
    return SelectableText(content);
  }

  static TextMessage fromJson(Json json) {
    return TextMessage(json["content"]);
  }

  @override
  Json toJson() {
    return {"content": content};
  }
}

class HelloMessage extends MessagePayload {
  String name;
  int port;

  HelloMessage({required this.name, required this.port});

  @override
  String get type => "hello";
  static String get stype => "hello";

  @override
  Widget widget(BuildContext _) {
    return MessagePayload.throw_no_widget();
  }

  static HelloMessage fromJson(Json json) {
    return HelloMessage(name: json["name"], port: json["port"]);
  }

  @override
  Json toJson() {
    return {"name": name, "port": port};
  }
}

class FileMessage extends MessagePayload {
  String filename;
  int size;

  FileMessage(this.filename, this.size);

  @override
  String get type => "file";
  static String get stype => "file";

  @override
  Widget widget(BuildContext context) {
    return Text("Shared file: '$filename'");
  }

  static FileMessage fromJson(Json json) {
    return FileMessage(json["filename"], json["size"]);
  }

  @override
  Json toJson() {
    return {"filename": filename, "size": size};
  }
}
