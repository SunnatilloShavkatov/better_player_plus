// Copyright 2018 the Dart project authors.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

import 'dart:math' show max;

import 'package:better_player_plus/src/visibility_detector/render_visibility_detector.dart';
import 'package:flutter/widgets.dart';

/// A [VisibilityDetector] widget fires a specified callback when the widget
/// changes visibility.
///
/// Callbacks are not fired immediately on visibility changes.  Instead,
/// callbacks are deferred and coalesced such that the callback for each
/// [VisibilityDetector] will be invoked at most once per
/// [VisibilityDetectorController.updateInterval] (unless forced by
/// [VisibilityDetectorController.notifyNow]).  Callbacks for *all*
/// [VisibilityDetector] widgets are fired together synchronously between
/// frames.
class VisibilityDetector extends SingleChildRenderObjectWidget {
  /// Constructor.
  ///
  /// `key` is required to properly identify this widget; it must be unique
  /// among all [VisibilityDetector] and [SliverVisibilityDetector] widgets.
  ///
  /// `onVisibilityChanged` may be `null` to disable this [VisibilityDetector].
  const VisibilityDetector({required Key key, required Widget child, required this.onVisibilityChanged})
    : super(key: key, child: child);

  /// The callback to invoke when this widget's visibility changes.
  final VisibilityChangedCallback? onVisibilityChanged;

  /// See [RenderObjectWidget.createRenderObject].
  @override
  RenderVisibilityDetector createRenderObject(BuildContext context) =>
      RenderVisibilityDetector(key: key!, onVisibilityChanged: onVisibilityChanged);

  /// See [RenderObjectWidget.updateRenderObject].
  @override
  void updateRenderObject(BuildContext context, RenderVisibilityDetector renderObject) {
    assert(renderObject.key == key, 'renderObject.key must equal key');
    renderObject.onVisibilityChanged = onVisibilityChanged;
  }
}

class SliverVisibilityDetector extends SingleChildRenderObjectWidget {
  /// Constructor.
  ///
  /// `key` is required to properly identify this widget; it must be unique
  /// among all [VisibilityDetector] and [SliverVisibilityDetector] widgets.
  ///
  /// `onVisibilityChanged` may be `null` to disable this
  /// [SliverVisibilityDetector].
  const SliverVisibilityDetector({required Key key, required Widget sliver, required this.onVisibilityChanged})
    : super(key: key, child: sliver);

  /// The callback to invoke when this widget's visibility changes.
  final VisibilityChangedCallback? onVisibilityChanged;

  /// See [RenderObjectWidget.createRenderObject].
  @override
  RenderSliverVisibilityDetector createRenderObject(BuildContext context) =>
      RenderSliverVisibilityDetector(key: key!, onVisibilityChanged: onVisibilityChanged);

  /// See [RenderObjectWidget.updateRenderObject].
  @override
  void updateRenderObject(BuildContext context, RenderSliverVisibilityDetector renderObject) {
    assert(renderObject.key == key, 'renderObject.key must equal key');
    renderObject.onVisibilityChanged = onVisibilityChanged;
  }
}

typedef VisibilityChangedCallback = void Function(VisibilityInfo info);

/// Data passed to the [VisibilityDetector.onVisibilityChanged] callback.
@immutable
class VisibilityInfo {
  /// Constructor.
  ///
  /// `key` corresponds to the [Key] used to construct the corresponding
  /// [VisibilityDetector] widget.  Must not be null.
  ///
  /// If `size` or `visibleBounds` are omitted, the [VisibilityInfo]
  /// will be initialized to [Offset.zero] or [Rect.zero] respectively.  This
  /// will indicate that the corresponding widget is competely hidden.
  const VisibilityInfo({required this.key, this.size = Size.zero, this.visibleBounds = Rect.zero});

  /// Constructs a [VisibilityInfo] from widget bounds and a corresponding
  /// clipping rectangle.
  ///
  /// [widgetBounds] and [clipRect] are expected to be in the same coordinate
  /// system.
  factory VisibilityInfo.fromRects({required Key key, required Rect widgetBounds, required Rect clipRect}) {
    final bool overlaps = widgetBounds.overlaps(clipRect);
    // Compute the intersection in the widget's local coordinates.
    final visibleBounds = overlaps ? widgetBounds.intersect(clipRect).shift(-widgetBounds.topLeft) : Rect.zero;

    return VisibilityInfo(key: key, size: widgetBounds.size, visibleBounds: visibleBounds);
  }

  /// The key for the corresponding [VisibilityDetector] widget.
  final Key key;

  /// The size of the widget.
  final Size size;

  /// The visible portion of the widget, in the widget's local coordinates.
  ///
  /// The bounds are reported using the widget's local coordinates to avoid
  /// expectations for the [VisibilityChangedCallback] to fire if the widget's
  /// position changes but retains the same visibility.
  final Rect visibleBounds;

  /// A fraction in the range \[0, 1\] that represents what proportion of the
  /// widget is visible (assuming rectangular bounding boxes).
  ///
  /// 0 means not visible; 1 means fully visible.
  double get visibleFraction {
    final visibleArea = _area(visibleBounds.size);
    final maxVisibleArea = _area(size);

    if (_floatNear(maxVisibleArea, 0)) {
      // Avoid division-by-zero.
      return 0;
    }

    var visibleFraction = visibleArea / maxVisibleArea;

    if (_floatNear(visibleFraction, 0)) {
      visibleFraction = 0;
    } else if (_floatNear(visibleFraction, 1)) {
      // The inexact nature of floating-point arithmetic means that sometimes
      // the visible area might never equal the maximum area (or could even
      // be slightly larger than the maximum).  Snap to the maximum.
      visibleFraction = 1;
    }

    assert(visibleFraction >= 0, 'visibleFraction must be >= 0');
    assert(visibleFraction <= 1, 'visibleFraction must be <= 1');
    return visibleFraction;
  }

  /// Returns true if the specified [VisibilityInfo] object has equivalent
  /// visibility to this one.
  bool matchesVisibility(VisibilityInfo info) => size == info.size && visibleBounds == info.visibleBounds;

  @override
  String toString() => 'VisibilityInfo(key: $key, size: $size visibleBounds: $visibleBounds)';

  @override
  int get hashCode => Object.hash(key, size, visibleBounds);

  @override
  bool operator ==(Object other) =>
      other is VisibilityInfo && other.key == key && other.size == size && other.visibleBounds == visibleBounds;
}

/// The tolerance used to determine whether two floating-point values are
/// approximately equal.
const _kDefaultTolerance = 0.01;

/// Computes the area of a rectangle of the specified dimensions.
double _area(Size size) {
  assert(size.width >= 0, 'size.width must be >= 0');
  assert(size.height >= 0, 'size.height must be >= 0');
  return size.width * size.height;
}

/// Returns whether two floating-point values are approximately equal.
bool _floatNear(double f1, double f2) {
  final absDiff = (f1 - f2).abs();
  return absDiff <= _kDefaultTolerance || (absDiff / max(f1.abs(), f2.abs()) <= _kDefaultTolerance);
}
