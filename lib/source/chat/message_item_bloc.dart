/*
 * OPEN-XCHANGE legal information
 *
 * All intellectual property rights in the Software are protected by
 * international copyright laws.
 *
 *
 * In some countries OX, OX Open-Xchange and open xchange
 * as well as the corresponding Logos OX Open-Xchange and OX are registered
 * trademarks of the OX Software GmbH group of companies.
 * The use of the Logos is not covered by the Mozilla Public License 2.0 (MPL 2.0).
 * Instead, you are allowed to use these Logos according to the terms and
 * conditions of the Creative Commons License, Version 2.5, Attribution,
 * Non-commercial, ShareAlike, and the interpretation of the term
 * Non-commercial applicable to the aforementioned license is published
 * on the web site https://www.open-xchange.com/terms-and-conditions/.
 *
 * Please make sure that third-party modules and libraries are used
 * according to their respective licenses.
 *
 * Any modifications to this package must retain all copyright notices
 * of the original copyright holder(s) for the original code used.
 *
 * After any such modifications, the original and derivative code shall remain
 * under the copyright of the copyright holder(s) and/or original author(s) as stated here:
 * https://www.open-xchange.com/legal/. The contributing author shall be
 * given Attribution for the derivative code and a license granting use.
 *
 * Copyright (C) 2016-2020 OX Software GmbH
 * Mail: info@open-xchange.com
 *
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the Mozilla Public License 2.0
 * for more details.
 */

import 'dart:async';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:delta_chat_core/delta_chat_core.dart';
import 'package:ox_talk/source/chat/message_item_event.dart';
import 'package:ox_talk/source/chat/message_item_state.dart';
import 'package:ox_talk/source/data/repository.dart';
import 'package:ox_talk/source/data/repository_manager.dart';
import 'package:ox_talk/source/utils/date.dart';
import 'package:ox_talk/source/utils/colors.dart';

class MessageItemBloc extends Bloc<MessageItemEvent, MessageItemState> {
  final Repository<Contact> _contactRepository = RepositoryManager.get(RepositoryType.contact);
  Repository<ChatMsg> _messagesRepository;
  int _messageId;
  int _contactId;
  bool _isGroupChat;

  @override
  MessageItemState get initialState => MessageItemStateInitial();

  @override
  Stream<MessageItemState> mapEventToState(MessageItemState currentState, MessageItemEvent event) async* {
    if (event is RequestMessage) {
      yield MessageItemStateLoading();
      try {
        _messagesRepository = RepositoryManager.get(RepositoryType.chatMessage, event.chatId);
        _messageId = event.messageId;
        _isGroupChat = event.isGroupChat;
        if (_isGroupChat) {
          _setupContact();
        }
        _setupMessage();
        dispatch(MessageLoaded());
      } catch (error) {
        yield MessageItemStateFailure(error: error.toString());
      }
    } else if (event is MessageLoaded) {
      ChatMsg message = _getMessage();
      bool isOutgoing = await message.isOutgoing();
      String text = await message.getText();
      bool hasFile = await message.hasFile();
      String timestamp = getTimeFromTimestamp(await message.getTimestamp());
      AttachmentWrapper attachment;
      if (hasFile) {
        attachment = AttachmentWrapper(
          filename: await message.getFileName(),
          path: await message.getFile(),
          mimeType: await message.getFileMime(),
          size: await message.getFileBytes(),
          type: await message.getType(),
        );
      }
      if (_isGroupChat) {
        Contact contact = _getContact();
        String contactName = await contact.getName();
        String contactAddress = await contact.getAddress();
        Color contactColor = rgbColorFromInt(await contact.getColor());
        yield MessageItemStateSuccess(
            attachmentWrapper: attachment,
            contactName: contactName,
            contactAddress: contactAddress,
            contactColor: contactColor,
            messageIsOutgoing: isOutgoing,
            messageText: text,
            hasFile: hasFile,
            messageTimestamp: timestamp);
      } else {
        yield MessageItemStateSuccess(
          attachmentWrapper: attachment,
          messageIsOutgoing: isOutgoing,
          messageText: text,
          hasFile: hasFile,
          messageTimestamp: timestamp,
        );
      }
    }
  }

  void _setupContact() async {
    ChatMsg message = _getMessage();
    _contactId = await message.getFromId();
    _getContact().loadValues(keys: [
      Contact.methodContactGetName,
      Contact.methodContactGetAddress,
      Contact.methodContactGetColor,
    ]);
  }

  void _setupMessage() async {
    _getMessage().loadValues(keys: [
      ChatMsg.methodMessageGetText,
      ChatMsg.methodMessageGetTimestamp,
      ChatMsg.methodMessageIsOutgoing,
      ChatMsg.methodMessageHasFile,
      ChatMsg.methodMessageGetFile,
      ChatMsg.methodMessageGetFileMime,
      ChatMsg.methodMessageGetType,
      ChatMsg.methodMessageGetFileBytes,
      ChatMsg.methodMessageGetFilename,
    ]);
  }

  Contact _getContact() {
    return _contactRepository.get(_contactId);
  }

  ChatMsg _getMessage() {
    return _messagesRepository.get(_messageId);
  }
}