// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'material.dart';
import 'text_field.dart';

class ContentField extends StatefulWidget {
  const ContentField(
      {Key? key, required this.controller, required this.focusNode})
      : super(key: key);

  final ReplacementTextEditingController controller;
  final FocusNode focusNode;

  @override
  State<ContentField> createState() => _ContentFieldState();
}

class InsertCharacterIntent extends Intent {
  const InsertCharacterIntent(this.character);

  final String character;

  @override
  bool consumesKey(Intent intent) => false;
}

class InsertCharacterAction extends Action<InsertCharacterIntent> {
  InsertCharacterAction(this.textModel);

  final SupplementaryTextModel textModel;

  @override
  void invoke(covariant InsertCharacterIntent intent) {
    // textModel.insertCharacter(intent.character);
  }
}

class _ContentFieldState extends State<ContentField> {
  SupplementaryTextModel textModel = SupplementaryTextModel();
  String? prevChar;
  bool lastKeyHasBeenReleased = true;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return DefaultTextEditingShortcuts(child: RawKeyboardListener(
          focusNode: widget.focusNode,
          onKey: (RawKeyEvent event) {
            // if (event.runtimeType.toString() == 'RawKeyDownEvent') {
            //   print('keydown ' + event.character.toString());
            // } else if (event.runtimeType.toString() == 'RawKeyUpEvent') {
            //   print('keyup ' + event.character.toString());
            // }
            if (event.runtimeType.toString() == 'RawKeyDownEvent' &&
                lastKeyHasBeenReleased) {
              final LogicalKeyboardKey logicalKey = event.logicalKey;
              final String? character = event.character;

              // Current diff data.
              String textChanged;
              int start;
              int end;
              String diffType;

              // Handle deletion.
              // if (logicalKey == LogicalKeyboardKey.backspace) {
              //   if (widget.controller.selection.start ==
              //       widget.controller.selection.end) {
              //     // Selection is collapsed, so we are deleting a single
              //     // character.
              //     textChanged = textModel.substring(
              //         widget.controller.selection.start - 1,
              //         widget.controller.selection.start);
              //     start = widget.controller.selection.start - 1;
              //     end = widget.controller.selection.start;
              //     diffType = 'DELETE';
              //
              //     print('deleting: ' +
              //         textModel.substring(widget.controller.selection.start - 1,
              //             widget.controller.selection.start) +
              //         ' start: ' +
              //         widget.controller.selection.start.toString() +
              //         ' end: ' +
              //         widget.controller.selection.end.toString());
              //     textModel = textModel.substring(
              //         0, widget.controller.selection.start - 1) +
              //         textModel.substring(
              //             widget.controller.selection.start, textModel.length);
              //   } else {
              //     // We are deleting a selection.
              //     textChanged = widget.controller.selection.textInside(textModel);
              //     start = widget.controller.selection.start;
              //     end = widget.controller.selection.end;
              //     diffType = 'DELETE';
              //
              //     print('deleting: ' +
              //         widget.controller.selection.textInside(textModel) +
              //         ' start: ' +
              //         widget.controller.selection.start.toString() +
              //         ' end: ' +
              //         widget.controller.selection.end.toString());
              //     textModel = widget.controller.selection.textBefore(textModel) +
              //         widget.controller.selection.textAfter(textModel);
              //   }
              //
              //   widget.controller
              //       .syncReplacementRanges(textChanged, start, end, diffType);
              // }

              // Handle character insertion.
              if (character != null && character != '') {
                if (prevChar != null && prevChar == character) {
                  lastKeyHasBeenReleased = false;
                } else if (prevChar != null && prevChar != character) {
                  lastKeyHasBeenReleased = true;
                }

                prevChar = character;

                if (lastKeyHasBeenReleased) {
                  // Don't insert if we are long pressing a character
                  // TODO: Vary this behavior per platform.
                  textChanged = character;
                  start = widget.controller.selection.start;
                  end = widget.controller.selection.end;
                  String? textReplaced;

                  if (widget.controller.selection.start ==
                      widget.controller.selection.end) {
                    diffType = 'INSERT';
                  } else {
                    diffType = 'REPLACE';
                    textReplaced =
                        widget.controller.selection.textInside(textModel.plainText);
                  }

                  // textModel = widget.controller.selection.textBefore(textModel) +
                  //     character +
                  //     widget.controller.selection.textAfter(textModel);

                  textModel.insertCharacter(widget.controller, character);

                  if (diffType == 'INSERT') {
                    print('$diffType: ' +
                        character +
                        ' start: ' +
                        widget.controller.selection.start.toString() +
                        ' end: ' +
                        widget.controller.selection.end.toString());
                  } else {
                    print('$diffType: ' +
                        textReplaced! +
                        ' with:' +
                        character +
                        ' start: ' +
                        widget.controller.selection.start.toString() +
                        ' end: ' +
                        widget.controller.selection.end.toString());
                  }

                  // _controller.syncTextAttributes(textChanged, start, end, diffType, textReplaced);
                  widget.controller.syncReplacementRanges(
                      textChanged, start, end, diffType, textReplaced);
                }
              }

              print(textModel.plainText);
            } else if (event.runtimeType.toString() == 'RawKeyDownEvent' &&
                !lastKeyHasBeenReleased) {
              // This long press key behavior may be limited to macOS.
              // On macOS you long press a key to make the native composing menu appear.
              // On windows long pressing a character prints out the character multiple times, same on Ubuntu.
              // On ubuntu you can disable long pressing causing repeated letter/symbol. You can also
              // change how long it takes before key presses start repeating or how quickly key presses
              // repeat in accessibility settings.
              //
              // On mac if you double space after a character a period appears after the character. How can we handle this?
              print('Holding past key');
            }

            if (event.runtimeType.toString() == 'RawKeyUpEvent') {
              // key up event character is always null on macOS, is this expected?
              // We can assume a key up event follows a key down event if we release the key,
              // if not we can assume it is still a key down event which means we have been
              // holding the key down.
              final String? character = event.character;

              lastKeyHasBeenReleased = true;

              prevChar = character;
            }
          },
          child: TextField(controller: widget.controller, supplementaryModel: textModel),
    ),
    );
    // return Shortcuts(
    //   shortcuts: <ShortcutActivator, Intent>{
    //     LogicalKeySet(LogicalKeyboardKey.keyA): const InsertCharacterIntent('a'),
    //   },
    //   child: Actions(
    //     actions: <Type, Action<Intent>>{
    //       InsertCharacterIntent: InsertCharacterAction(textModel)
    //     },
    //     child: TextField(controller: widget.controller),
    //   ),
    // );
    // return RawKeyboardListener(
    //   focusNode: widget.focusNode,
    //   onKey: (RawKeyEvent event) {
    //     // if (event.runtimeType.toString() == 'RawKeyDownEvent') {
    //     //   print('keydown ' + event.character.toString());
    //     // } else if (event.runtimeType.toString() == 'RawKeyUpEvent') {
    //     //   print('keyup ' + event.character.toString());
    //     // }
    //     if (event.runtimeType.toString() == 'RawKeyDownEvent' &&
    //         lastKeyHasBeenReleased) {
    //       final LogicalKeyboardKey logicalKey = event.logicalKey;
    //       final String? character = event.character;
    //
    //       // Current diff data.
    //       String textChanged;
    //       int start;
    //       int end;
    //       String diffType;
    //
    //       // Handle deletion.
    //       if (logicalKey == LogicalKeyboardKey.backspace) {
    //         if (widget.controller.selection.start ==
    //             widget.controller.selection.end) {
    //           // Selection is collapsed, so we are deleting a single
    //           // character.
    //           textChanged = textModel.substring(
    //               widget.controller.selection.start - 1,
    //               widget.controller.selection.start);
    //           start = widget.controller.selection.start - 1;
    //           end = widget.controller.selection.start;
    //           diffType = 'DELETE';
    //
    //           print('deleting: ' +
    //               textModel.substring(widget.controller.selection.start - 1,
    //                   widget.controller.selection.start) +
    //               ' start: ' +
    //               widget.controller.selection.start.toString() +
    //               ' end: ' +
    //               widget.controller.selection.end.toString());
    //           textModel = textModel.substring(
    //               0, widget.controller.selection.start - 1) +
    //               textModel.substring(
    //                   widget.controller.selection.start, textModel.length);
    //         } else {
    //           // We are deleting a selection.
    //           textChanged = widget.controller.selection.textInside(textModel);
    //           start = widget.controller.selection.start;
    //           end = widget.controller.selection.end;
    //           diffType = 'DELETE';
    //
    //           print('deleting: ' +
    //               widget.controller.selection.textInside(textModel) +
    //               ' start: ' +
    //               widget.controller.selection.start.toString() +
    //               ' end: ' +
    //               widget.controller.selection.end.toString());
    //           textModel = widget.controller.selection.textBefore(textModel) +
    //               widget.controller.selection.textAfter(textModel);
    //         }
    //
    //         widget.controller
    //             .syncReplacementRanges(textChanged, start, end, diffType);
    //       }
    //
    //       // Handle character insertion.
    //       if (character != null && character != '') {
    //         if (prevChar != null && prevChar == character) {
    //           lastKeyHasBeenReleased = false;
    //         } else if (prevChar != null && prevChar != character) {
    //           lastKeyHasBeenReleased = true;
    //         }
    //
    //         prevChar = character;
    //
    //         if (lastKeyHasBeenReleased) {
    //           // Don't insert if we are long pressing a character
    //           // TODO: Vary this behavior per platform.
    //           textChanged = character;
    //           start = widget.controller.selection.start;
    //           end = widget.controller.selection.end;
    //           String? textReplaced;
    //
    //           if (widget.controller.selection.start ==
    //               widget.controller.selection.end) {
    //             diffType = 'INSERT';
    //           } else {
    //             diffType = 'REPLACE';
    //             textReplaced =
    //                 widget.controller.selection.textInside(textModel);
    //           }
    //
    //           textModel = widget.controller.selection.textBefore(textModel) +
    //               character +
    //               widget.controller.selection.textAfter(textModel);
    //
    //           if (diffType == 'INSERT') {
    //             print('$diffType: ' +
    //                 character +
    //                 ' start: ' +
    //                 widget.controller.selection.start.toString() +
    //                 ' end: ' +
    //                 widget.controller.selection.end.toString());
    //           } else {
    //             print('$diffType: ' +
    //                 textReplaced! +
    //                 ' with:' +
    //                 character +
    //                 ' start: ' +
    //                 widget.controller.selection.start.toString() +
    //                 ' end: ' +
    //                 widget.controller.selection.end.toString());
    //           }
    //
    //           // _controller.syncTextAttributes(textChanged, start, end, diffType, textReplaced);
    //           widget.controller.syncReplacementRanges(
    //               textChanged, start, end, diffType, textReplaced);
    //         }
    //       }
    //
    //       print(textModel);
    //     } else if (event.runtimeType.toString() == 'RawKeyDownEvent' &&
    //         !lastKeyHasBeenReleased) {
    //       // This long press key behavior may be limited to macOS.
    //       // On macOS you long press a key to make the native composing menu appear.
    //       // On windows long pressing a character prints out the character multiple times, same on Ubuntu.
    //       // On ubuntu you can disable long pressing causing repeated letter/symbol. You can also
    //       // change how long it takes before key presses start repeating or how quickly key presses
    //       // repeat in accessibility settings.
    //       //
    //       // On mac if you double space after a character a period appears after the character. How can we handle this?
    //       print('Holding past key');
    //     }
    //
    //     if (event.runtimeType.toString() == 'RawKeyUpEvent') {
    //       // key up event character is always null on macOS, is this expected?
    //       // We can assume a key up event follows a key down event if we release the key,
    //       // if not we can assume it is still a key down event which means we have been
    //       // holding the key down.
    //       final String? character = event.character;
    //
    //       lastKeyHasBeenReleased = true;
    //
    //       prevChar = character;
    //     }
    //   },
    //   autofocus: true,
    //   child: TextField(
    //     controller: widget.controller,
    //   ),
    // );
  }
}