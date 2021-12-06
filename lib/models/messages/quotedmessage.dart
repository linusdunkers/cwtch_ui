import 'dart:convert';

import 'package:cwtch/models/message.dart';
import 'package:cwtch/models/messages/malformedmessage.dart';
import 'package:cwtch/widgets/messagerow.dart';
import 'package:cwtch/widgets/quotedmessage.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../model.dart';

class QuotedMessageStructure {
  final String quotedHash;
  final String body;
  QuotedMessageStructure(this.quotedHash, this.body);

  Map<String, dynamic> toJson() => {
        'quotedHash': quotedHash,
        'body': body,
      };
}

class LocallyIndexedMessage {
  final dynamic message;
  final int index;

  LocallyIndexedMessage(this.message, this.index);

  LocallyIndexedMessage.fromJson(Map<String, dynamic> json)
      : message = json['Message'],
        index = json['LocalIndex'];

  Map<String, dynamic> toJson() => {
        'Message': message,
        'LocalIndex': index,
      };
}

class QuotedMessage extends Message {
  final MessageMetadata metadata;
  final String content;
  QuotedMessage(this.metadata, this.content);

  @override
  Widget getPreviewWidget(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: this.metadata,
        builder: (bcontext, child) {
          try {
            dynamic message = jsonDecode(this.content);
            return Text(message["body"]);
          } catch (e) {
            return MalformedMessage(this.metadata).getWidget(context, Key("malformed"));
          }
        });
  }

  @override
  MessageMetadata getMetadata() {
    return this.metadata;
  }

  @override
  Widget getWidget(BuildContext context, Key key) {
    try {
      dynamic message = jsonDecode(this.content);

      if (message["body"] == null || message["quotedHash"] == null) {
        return MalformedMessage(this.metadata).getWidget(context, key);
      }

      var quotedMessagePotentials = Provider.of<FlwtchState>(context).cwtch.GetMessageByContentHash(metadata.profileOnion, metadata.conversationIdentifier, message["quotedHash"]);
      Future<LocallyIndexedMessage?> quotedMessage = quotedMessagePotentials.then((matchingMessages) {
        if (matchingMessages == "[]") {
          return null;
        }
        // reverse order the messages from newest to oldest and return the
        // first matching message where it's index is less than the index of this
        // message
        try {
          var list = (jsonDecode(matchingMessages) as List<dynamic>).map((data) => LocallyIndexedMessage.fromJson(data)).toList();
          LocallyIndexedMessage candidate = list.reversed.first;
          return candidate;
        } catch (e) {
          // Malformed Message will be returned...
          return null;
        }
      });

      return ChangeNotifierProvider.value(
          value: this.metadata,
          builder: (bcontext, child) {
            return MessageRow(
                QuotedMessageBubble(message["body"], quotedMessage.then((LocallyIndexedMessage? localIndex) {
                  if (localIndex != null) {
                    return messageHandler(context, metadata.profileOnion, metadata.conversationIdentifier, localIndex.index);
                  }
                  return MalformedMessage(this.metadata);
                })),
                key: key);
          });
    } catch (e) {
      return MalformedMessage(this.metadata).getWidget(context, key);
    }
  }
}
