import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:didactic_waddle/chat_input.dart';
import 'package:didactic_waddle/l10n/app_localizations.dart';
import 'package:didactic_waddle/log.dart';
import 'package:didactic_waddle/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:toml/toml.dart';
import 'package:uuid7/uuid7.dart';

late Map<String, dynamic> default_config;
late Box config;

final broadcast_addr = InternetAddress("255.255.255.255");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  default_config = TomlDocument.parse(
    (await rootBundle.loadString("assets/config.default.toml")),
  ).toMap();

  await Hive.initFlutter();
  config = await Hive.openBox("config");

  await first_init();
  runApp(const Application());
}

Future<void> first_init() async {
  if (!config.containsKey("name")) {
    await config.put("name", "user_${Random().nextInt(255)}");
  }
  if (!config.containsKey("user_id")) {
    await config.put("user_id", Uuid7.gen().toString());
  }
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FThemes.zinc.dark;

    return MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
      ],
      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) => FAnimatedTheme(data: theme, child: child!),
      home: const FScaffold(child: SafeArea(child: Example())),
    );
  }
}

final dfmt = DateFormat("HH:mm:ss dd-MM-yyyy");

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class User {
  String id;
  String name;
  InternetAddress addr;
  int port;

  User({
    required this.id,
    required this.name,
    required this.addr,
    required this.port,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is User && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return "User(id='$id', name='$name', host='${addr.address}:$port')";
  }

  String get host => "${addr.address}:$port";
}

class _ExampleState extends State<Example> {
  final List<Message> _messages = [];
  final ScrollController _scroll_ctr = ScrollController();
  final Map<String, User> _users = {};
  late RawDatagramSocket _public_sock;
  late ServerSocket _server_sock;
  Socket? _client_sock;

  void _scroll_to_end() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll_ctr.hasClients) {
        _scroll_ctr.animateTo(
          _scroll_ctr.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scroll_to_end();

    for (int i = 0; i < 20; i++) {
      _messages.add(
        Message(
          header: MessageHeader(
            user_id: config.get("user_id"),
            type: TextMessage.stype,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              DateTime.now().toUtc().millisecondsSinceEpoch + i * 1000,
            ),
          ),
          payload: TextMessage("Message placeholder"),
        ),
      );
    }
    _users[config.get("user_id")] = User(
      id: config.get("user_id"),
      name: "Me: '${config.get("name")}'",
      addr: InternetAddress.anyIPv4,
      port: -1,
    );

    _async_init_state();
  }

  Future<void> _async_init_state() async {
    // _public_sock
    {
      _public_sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        default_config["channels"]["public"]["port"],
        reuseAddress: true,
        reusePort: true,
      );
      _public_sock.broadcastEnabled = true;
      _public_sock.listen((RawSocketEvent event) async {
        if (event == RawSocketEvent.read) {
          log.i(event);
          final pkt = _public_sock.receive()!;
          final msg_str = utf8.decode(pkt.data);
          Map<String, dynamic>? msg_dyn;
          try {
            msg_dyn = jsonDecode(msg_str);
          } on FormatException catch (_) {
            log.i("Failed to parse message");
            return;
          }

          final Message msg = Message.fromJson(msg_dyn!, config);
          if (msg.header.user_id == config.get("user_id")) {
            return;
          }

          final Map<String, void Function()> foo = {
            "hello": () {
              final hm = msg.payload as HelloMessage;
              final user = User(
                id: msg.header.user_id,
                name: hm.name,
                addr: pkt.address,
                port: hm.port,
              );
              if (_users.containsKey(user.id)) {
                final saved_user = _users[user.id]!;
                if (saved_user.addr.address != user.addr.address ||
                    saved_user.port != user.port) {
                  log.d(
                    "Change host. "
                    "old='${saved_user.host}'"
                    "new='${user.host}'",
                  );
                  saved_user.addr = user.addr;
                  saved_user.port = user.port;
                }
              } else {
                _send_hello(_server_sock.port);
                _users[user.id] = user;
                log.i("New user: $user");
              }
            },
          };
          if (foo.containsKey(msg.header.type)) {
            foo[msg.header.type]!.call();
          } else {
            setState(() {
              _messages.add(msg);
            });
          }
        }
      });
    }

    // _server_sock
    {
      _server_sock = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        default_config["channels"]["main"]["port"],
        shared: false,
      );

      _server_sock.listen((Socket client) {
        ;
      });
    }

    _send_hello(_server_sock.port);
  }

  Future<void> _send_hello(int server_port, [int times = 3]) async {
    final msg = utf8.encode(
      json.encode(
        Message(
          header: MessageHeader(
            user_id: config.get("user_id"),
            type: HelloMessage.stype,
          ),
          payload: HelloMessage(name: config.get("name"), port: server_port),
        ),
      ),
    );
    final port =
        config.get("port") ?? default_config["channels"]["public"]["port"];
    bool first = true;
    for (int i = 0; i < times; i++) {
      _public_sock.send(msg, broadcast_addr, port);
      if (first) {
        first = false;
      } else {
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }
  }

  @override
  void dispose() {
    _public_sock.close();
    _server_sock.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_messages.isNotEmpty) {
                  return ListView.builder(
                    reverse: true,
                    padding: EdgeInsetsGeometry.only(left: 12, right: 12),
                    itemCount: _messages.length,
                    itemBuilder: (BuildContext context, int i) {
                      final msg = _messages[_messages.length - i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 3),
                        child: FTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _users[msg.header.user_id]?.name ?? "Unknown",
                                style: context.theme.typography.sm.copyWith(
                                  color: context.theme.colors.mutedForeground,
                                ),
                              ),
                              msg.payload.widget(context),
                            ],
                          ),
                          suffix: Text(
                            dfmt.format(msg.header.timestamp.toLocal()),
                            style: context.theme.typography.xs.copyWith(
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  final typography = context.theme.typography;
                  final colors = context.theme.colors;
                  return Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0, 5, 0, 5),
                    child: Text(
                      "No messages...",
                      style: typography.base.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12),
            child: ChatInput(on_message: _send_message),
          ),
        ],
      ),
    ),
  );

  Future<void> _send_message(MessagePayload payload) async {
    final msg = Message(
      header: MessageHeader(user_id: config.get("user_id"), type: payload.type),
      payload: payload,
    );
    _public_sock.send(
      utf8.encode(json.encode(msg)),
      broadcast_addr,
      config.get("port") ?? default_config["channels"]["public"]["port"],
    );
    setState(() {
      _messages.add(msg);
    });
  }
}
