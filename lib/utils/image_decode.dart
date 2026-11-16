import 'package:flutter/widgets.dart';

/// Pixel size to decode an image at, for a slot [logicalSize] logical pixels
/// wide on this screen.
///
/// Uploaded photos are often ~4000 px wide; decoding them at full size into
/// a small slot wastes memory and can crash low-end phones. Pass this as
/// `cacheWidth` / `memCacheWidth` / `ResizeImage(width:)`. Only the width is
/// constrained, so the aspect ratio is kept. For `BoxFit.cover` thumbnails,
/// pass about twice the slot width so wide photos stay sharp after cropping.
int decodeWidth(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context)).ceil();

/// [decodeWidth] for an image that spans the screen width.
int screenDecodeWidth(BuildContext context) =>
    decodeWidth(context, MediaQuery.sizeOf(context).width);
