// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;

enum _GestureState {
  ready,
  possible,
  accepted,
}

/// {@macro flutter.gestures.tap.GestureTapDownCallback}
///
/// The consecutive tap count at the time the pointer contacted the screen is given by [TapStatus.consecutiveTapCount].
///
/// Used by [TapAndDragGestureRecognizer.onTapDown].
typedef GestureTapDownWithTapStatusCallback  = void Function(TapDownDetails details, TapStatus status);

/// {@macro flutter.gestures.tap.GestureTapUpCallback}
///
/// The consecutive tap count at the time the pointer contacted the screen is given by [TapStatus.consecutiveTapCount].
///
/// Used by [TapAndDragGestureRecognizer.onTapUp].
typedef GestureTapUpWithTapStatusCallback  = void Function(TapUpDetails details, TapStatus status);

/// {@macro flutter.gestures.dragdetails.GestureDragStartCallback}
///
/// The consecutive tap count when the drag was initiated is given by [TapStatus.consecutiveTapCount].
///
/// Used by [TapAndDragGestureRecognizer.onStart].
typedef GestureDragStartWithTapStatusCallback = void Function(DragStartDetails details, TapStatus status);

/// {@macro flutter.gestures.dragdetails.GestureDragUpdateCallback}
///
/// The consecutive tap count when the drag was initiated is given by [TapStatus.consecutiveTapCount].
///
/// Used by [TapAndDragGestureRecognizer.onUpdate].
typedef GestureDragUpdateWithTapStatusCallback = void Function(DragUpdateDetails details, TapStatus status);

/// {@macro flutter.gestures.monodrag.GestureDragEndCallback}
///
/// The consecutive tap count when the drag was initiated is given by [TapStatus.consecutiveTapCount].
///
/// Used by [TapAndDragGestureRecognizer.onEnd].
typedef GestureDragEndWithTapStatusCallback = void Function(DragEndDetails endDetails, TapStatus status);

/// An object that includes supplementary details of a tap event, such as
/// the keys that were pressed when tap down occured, and what the tap count
/// is.
class TapStatus {
  /// Creates a [TapStatus].
  const TapStatus({
    required this.consecutiveTapCount,
    required this.keysPressedOnDown,
  });

  /// If this tap is in a series of taps, the `consecutiveTapCount` is
  /// what number in the series this tap is.
  final int consecutiveTapCount;

  /// The keys that were pressed when the most recent `PointerDownEvent` occurred.
  final Set<LogicalKeyboardKey> keysPressedOnDown;
}

// A mixin for [OneSequenceGestureRecognizer] that tracks the number of taps
// that occur in a series of [PointerEvent]'s and the most recent set of
// [LogicalKeyboardKey]'s pressed on the most recent tap down.
//
// A tap is tracked as part of a series of taps if:
//
// 1. The elapsed time between when a [PointerUpEvent] and the subsequent
// [PointerDownEvent] does not exceed `kDoubleTapTimeout`.
// 2. The delta between the position tapped in the global coordinate system
// and the position that was tapped previously must be less than or equal
// to `kDoubleTapSlop`.
// 3. The tap being tracked does not become a drag.
//
// This mixin's state, i.e. the series of taps being tracked is reset when 
// a tap is tracked that does not meet any of the specifications stated above.
mixin _TapStatusTrackerMixin on OneSequenceGestureRecognizer {
  // Public state available to [OneSequenceGestureRecognizer].
  PointerDownEvent? get currentDown => _down;
  PointerUpEvent? get currentUp => _up;
  int get consecutiveTapCount => _consecutiveTapCount;
  Set<LogicalKeyboardKey> get keysPressedOnDown => _keysPressedOnDown ?? <LogicalKeyboardKey>{};
  bool get _pastTapTolerance => _pastTapTolerance;

  // Private tap state tracked.
  PointerDownEvent? _down;
  PointerUpEvent? _up;
  int _consecutiveTapCount = 0;
  Set<LogicalKeyboardKey>? _keysPressedOnDown;
  bool _pastTapTolerance = false;

  // For timing taps.
  Timer? _consecutiveTapTimer;
  Offset? _lastTapOffset;

  int? _previousButtons;

  bool _wonArena = false;

  OffsetPair? _initialPosition;

  @override
  void didStopTrackingLastPointer(int pointer) {
    _initialPosition = null;
  }

  // When we start to track a tap, we can choose to increment the 
  // `consecutiveTapCount` if the given tap falls under the tolerance specifications
  // or we can reset the count to 1. 
  //
  // We should not reset the tap count due to a timeout because a drag may be occuring.
  // Hmm, but technically the timer should not be active during a drag so a timeout
  // should not be possible because the timer is cancelled on down and not resumed until
  // a PointerUpEvent is received. make sure of this.
  @override
  void addAllowedPointer(PointerDownEvent event) {
    print('tracking from mixin');
    _up = null;
    _pastTapTolerance = false;
    _initialPosition = OffsetPair(local: event.localPosition, global: event.position);
    if (_down != null && !_representsSameSeries(event)) {
      // The given tap does not match the specifications of the series of taps being tracked,
      // reset the tap count and related state.
      _consecutiveTapCount = 1;
      print('reset');
    } else {
      _consecutiveTapCount += 1;
      print('increment');
    }
    _consecutiveTapTimerStop();
    _trackTrap(event);

    // The super class is called once the `consecutiveTapCount` is updated,
    // so the [OneSequenceGestureRecognizer] has an accurate count. In this case
    // [BaseDragGestureRecognizer.addAllowedPointer] is called.
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    print('accept from mixin');
    _wonArena = true;
    if (_up != null && _down != null) {
      print('up');
      _consecutiveTapTimerStop();
      _consecutiveTapTimerStart();
      _wonArena = false;
    }
  }

  double _getGlobalDistance(PointerEvent event) {
    assert(_initialPosition != null);
    final Offset offset = event.position - _initialPosition!.global;
    return offset.distance;
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    print('handle event from mixin');
    if (event is PointerMoveEvent) {
      final bool isPreAcceptSlopPastTolerance =
          !_wonArena &&
          _getGlobalDistance(event) > kTouchSlop!;
      final bool isPostAcceptSlopPastTolerance =
          _wonArena &&
          _getGlobalDistance(event) > kTouchSlop;
      
      if (isPreAcceptSlopPastTolerance || isPostAcceptSlopPastTolerance) {
        _pastTapTolerance = true;
      }
    } else if (event is PointerUpEvent) {
      _up = event;
      if (_wonArena && _up != null && _down != null) {
        print('up from handle event mixin');
        _consecutiveTapTimerStop();
        _consecutiveTapTimerStart();
        _wonArena = false;
      }
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _consecutiveTapTimerReset();
  }

  @override
  void dispose() {
    _consecutiveTapTimerReset();
    super.dispose();
  }
 
  void _trackTrap(PointerDownEvent event) {
    _down = event;
    _keysPressedOnDown = HardwareKeyboard.instance.logicalKeysPressed;
    _previousButtons = event.buttons;
    _lastTapOffset = event.position;
  }

  bool _hasSameButton(int buttons) {
    assert(_previousButtons != null);
    if (buttons == _previousButtons!) {
      return true;
    } else {
      return false;
    }
  }

  bool _isWithinConsecutiveTapTolerance(Offset secondTapOffset) {
    assert(secondTapOffset != null);
    if (_lastTapOffset == null) {
      return false;
    }

    final Offset difference = secondTapOffset - _lastTapOffset!;
    return difference.distance <= kDoubleTapSlop;
  }

  bool _representsSameSeries(PointerDownEvent event) {
    return _consecutiveTapTimer != null
        && _isWithinConsecutiveTapTolerance(event.position)
        && _hasSameButton(event.buttons);
  }

  void _consecutiveTapTimerStart() {
    print('start');
    _consecutiveTapTimer ??= Timer(kDoubleTapTimeout, _consecutiveTapTimerReset);
  }

  void _consecutiveTapTimerStop() {
    if (_consecutiveTapTimer != null) {
      print('stop');
      _consecutiveTapTimer!.cancel();
      _consecutiveTapTimer = null;
    } else {
      print('tried to stop');
    }
  }

  void _consecutiveTapTimerReset() {
    // The timer has timed out, i.e. the time between a [PointerUpEvent] and the subsequent
    // [PointerDownEvent] exceeded the duration of `kDoubleTapTimeout`, so the tap belonging
    // to the [PointerDownEvent] cannot be considered part of the same tap series as the
    // previous [PointerUpEvent].
    _consecutiveTapTimerStop();
    _previousButtons = null;
    _lastTapOffset = null;
    _consecutiveTapCount = 0;
    _keysPressedOnDown = null;
    _down = null;
    _up = null;
    print('timeout');
  }
}

/// Recognizes taps and movements.
///
/// Takes on the responsibilities of [TapGestureRecognizer] and [DragGestureRecognizer] in one [GestureRecognizer].
class TapAndDragGestureRecognizer extends BaseDragGestureRecognizer with _TapStatusTrackerMixin {
  /// Initialize the object.
  ///
  /// [dragStartBehavior] must not be null.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  TapAndDragGestureRecognizer({
    super.dragStartBehavior,
    super.debugOwner,
    super.kind,
    super.supportedDevices,
  });

  @override
  GestureTapDownWithTapStatusCallback? onTapDown;

  @override
  GestureTapUpWithTapStatusCallback? onTapUp;

  @override
  GestureTapCancelCallback? onTapCancel;

  @override
  GestureTapDownCallback? onSecondaryTapDown;

  @override
  GestureTapCallback? onSecondaryTap;

  @override
  GestureTapUpCallback? onSecondaryTapUp;

  @override
  GestureTapCancelCallback? onSecondaryTapCancel;

  @override
  GestureDragStartWithTapStatusCallback? onStart;

  @override
  GestureDragUpdateWithTapStatusCallback? onUpdate;

  @override
  GestureDragEndWithTapStatusCallback? onEnd;

  @override
  GestureDragCancelCallback? onDragCancel;

  bool _declaredWinner = false;

  bool _isDrag = false;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (initialButtons == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onTapDown == null &&
              onStart == null &&
              onUpdate == null &&
              onEnd == null &&
              onTapUp == null &&
              onTapCancel == null &&
              onDragCancel == null) {
            return false;
          }
          break;
        case kSecondaryButton:
          if (onSecondaryTap == null &&
              onSecondaryTapDown == null &&
              onSecondaryTapUp == null &&
              onSecondaryTapCancel == null) {
            return false;
          }
          break;
        default:
          return false;
      }
    } else {
      // There can be multiple drags simultaneously. Their effects are combined.
      if (event.buttons != initialButtons) {
        return false;
      }
    }
    return true;
    // return (this as OneSequenceGestureRecognizer).isPointerAllowed(event as PointerDownEvent);
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    print('accept from recognizer');
    _declaredWinner = true;
    if (currentUp != null && currentDown != null) {
      print('accept recognizer - tryign tap up');
      _checkTapUp();
    }
  }

  void _checkTapUp() {
    assert(currentUp != null);
    if (!_declaredWinner) {
      print('didnt win arena up');
      return;
    }
    _declaredWinner = false;
    print('won arena up');

    final TapUpDetails upDetails = TapUpDetails(
      kind: currentUp!.kind,
      globalPosition: currentUp!.position,
      localPosition: currentUp!.localPosition,
    );

    final TapStatus status = TapStatus(
      consecutiveTapCount: consecutiveTapCount,
      keysPressedOnDown: keysPressedOnDown,
    );

    print(initialButtons);

    switch (initialButtons) {
      case kPrimaryButton:
        if (onTapUp != null) {
          print('whet');
          invokeCallback('onTapUp', () => onTapUp!(upDetails, status));
        }
        break;
      case kSecondaryButton:
        if (onSecondaryTapUp != null) {
          invokeCallback('onSecondaryTapUp', () => onSecondaryTapUp!(upDetails));
        }
        if (onSecondaryTap != null) {
          print('secondary tap');
          invokeCallback<void>('onSecondaryTap', () => onSecondaryTap!());
        }
        break;
      default:
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    // If we arrive at a [PointerUpEvent] it can mean one of two things.
    // 1. A tap has completed.
    // 2. A drag has completed.
    // Calling super.handleEvent will immediately process this event as a
    // drag. First we will reason if the [PointerUpEvent] received is associated
    // with a tap or drag. If it is a tap then `_checkTapUp` will be called with
    // `onDragCancel`. If a drag, then super.handleEvent will run as normal, and
    // `onTapCancel` will be called.
    if (event is PointerMoveEvent || event is PointerPanZoomUpdateEvent) {
      final Offset delta = (event is PointerMoveEvent) ? event.delta : (event as PointerPanZoomUpdateEvent).panDelta;
      final Offset localDelta = (event is PointerMoveEvent) ? event.localDelta : (event as PointerPanZoomUpdateEvent).localPanDelta;
      final Offset position = (event is PointerMoveEvent) ? event.position : (event.position + (event as PointerPanZoomUpdateEvent).pan);
      final Offset localPosition = (event is PointerMoveEvent) ? event.localPosition : (event.localPosition + (event as PointerPanZoomUpdateEvent).localPan);
      if (dragState != DragState.accepted) {
        final Offset movedLocally = getDeltaForDetails(localDelta);
        final Matrix4? localToGlobalTransform = event.transform == null ? null : Matrix4.tryInvert(event.transform!);
        globalDistanceMoved += PointerEvent.transformDeltaViaPositions(
          transform: localToGlobalTransform,
          untransformedDelta: movedLocally,
          untransformedEndPosition: localPosition
        ).distance * (getPrimaryValueFromOffset(movedLocally) ?? 1).sign;
        if (hasSufficientGlobalDistanceToAccept(event.kind, gestureSettings?.touchSlop)) {
          _isDrag = true;
        }
      }
    }
    super.handleEvent(event);
    print('handle event from recognizer ${event.runtimeType}');
    if (event is PointerUpEvent) {
      print('handle event pointer up recognizer $_declaredWinner');
      if (currentUp != null && currentDown != null) {
        print('trying up');
        _checkTapUp();
      }
    }
    print('suspicius');
  }

  @protected
  @override
  void handleDragDown({ required PointerEvent down }) {
    if (onTapDown != null) {
      print('hello from handle drag down');
      final TapDownDetails details = TapDownDetails(
        globalPosition: down.position,
        localPosition: down.localPosition,
        kind: getKindForPointer(down.pointer),
      );

      final TapStatus status = TapStatus(
        consecutiveTapCount: consecutiveTapCount,
        keysPressedOnDown: keysPressedOnDown,
      );

      switch (initialButtons) {
        case kPrimaryButton:
          if (onTapDown != null) {
            invokeCallback('onTapDown', () => onTapDown!(details, status));
          }
          break;
        case kSecondaryButton:
          if (onSecondaryTapDown != null) {
            print('hello from secondary');
            invokeCallback('onSecondaryTapDown', () => onSecondaryTapDown!(details));
          }
          break;
        default:
      }
    }
  }

  @protected
  @override
  void handleDragStart({ 
    required Duration timestamp, 
    required int pointer, 
    required OffsetPair dragOrigin,
  }) {
      if (onStart != null) {
        final DragStartDetails details = DragStartDetails(
          sourceTimeStamp: timestamp,
          globalPosition: dragOrigin.global,
          localPosition: dragOrigin.local,
          kind: getKindForPointer(pointer),
        );

        final TapStatus status = TapStatus(
          consecutiveTapCount: consecutiveTapCount,
          keysPressedOnDown: keysPressedOnDown,
        );

        invokeCallback<void>('onStart', () => onStart!(details, status));
    }
  }
  
  @protected
  @override
  void handleDragUpdate({
    Duration? sourceTimeStamp,
    required Offset delta,
    double? primaryDelta,
    required int pointer,
    required OffsetPair dragOrigin,
    required Offset globalPosition,
    required Offset localPosition,
  }) {
    if (onUpdate != null) {
      final DragUpdateDetails details =  DragUpdateDetails(
        sourceTimeStamp: sourceTimeStamp,
        delta: delta,
        primaryDelta: primaryDelta,
        globalPosition: globalPosition,
        kind: getKindForPointer(pointer),
        localPosition: localPosition,
        offsetFromOrigin: globalPosition - dragOrigin.global,
        localOffsetFromOrigin: localPosition - dragOrigin.local,
      );

      final TapStatus status = TapStatus(
        consecutiveTapCount: consecutiveTapCount,
        keysPressedOnDown: keysPressedOnDown,
      );

      invokeCallback<void>('onUpdate', () => onUpdate!(details, status));
    }
  }

  @protected
  @override
  void handleDragEnd({ required VelocityTracker tracker }) {
    if (onEnd != null) {
      final DragEndDetails endDetails = DragEndDetails(primaryVelocity: 0.0);

      final TapStatus status = TapStatus(
        consecutiveTapCount: consecutiveTapCount,
        keysPressedOnDown: keysPressedOnDown,
      );

      invokeCallback<void>('onEnd', () => onEnd!(endDetails, status));
    }
  }

  @protected
  @override
  void handleDragCancel() {
    if (onDragCancel != null) {
      invokeCallback<void>('onDragCancel', onDragCancel!);
    }
  }

  // To enable panning.
  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
    return estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity
        && estimate.offset.distanceSquared > minDistance * minDistance;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved.abs() > computePanSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset getDeltaForDetails(Offset delta) => delta;

  @override
  double? getPrimaryValueFromOffset(Offset value) => null;

  @override
  String get debugDescription => 'tap_and_drag';
}
