// Flutter imports:
import 'package:flutter/material.dart';

///Configuration of subtitles - colors/padding/font. Used in
///BetterPlayerConfiguration.
class BetterPlayerSubtitlesConfiguration {
  ///Subtitle font size
  final double fontSize;

  ///Subtitle font color
  final Color fontColor;

  ///Enable outline (border) of the text
  final bool outlineEnabled;

  ///Color of the outline stroke
  final Color outlineColor;

  ///Outline stroke size
  final double outlineSize;

  ///Font family of the subtitle
  final String fontFamily;

  ///Left padding of the subtitle
  final double leftPadding;

  ///Right padding of the subtitle
  final double rightPadding;

  ///Bottom padding of the subtitle
  final double bottomPadding;

  ///Alignment of the subtitle
  final Alignment alignment;

  ///Background color of the subtitle
  final Color backgroundColor;

  ///Subtitle text alignment
  final TextAlign textAlign;

  const BetterPlayerSubtitlesConfiguration({
    this.fontSize = 14,
    this.fontColor = Colors.white,
    this.outlineEnabled = true,
    this.outlineColor = Colors.black,
    this.outlineSize = 2.0,
    this.fontFamily = "Roboto",
    this.leftPadding = 8.0,
    this.rightPadding = 8.0,
    this.bottomPadding = 20.0,
    this.alignment = Alignment.center,
    this.backgroundColor = Colors.transparent,
    this.textAlign = TextAlign.center,
  });

  BetterPlayerSubtitlesConfiguration copyWith({
    double? fontSize,
    Color? fontColor,
    bool? outlineEnabled,
    Color? outlineColor,
    double? outlineSize,
    String? fontFamily,
    double? leftPadding,
    double? rightPadding,
    double? bottomPadding,
    Alignment? alignment,
    Color? backgroundColor,
    TextAlign? textAlign,
  }) {
    return BetterPlayerSubtitlesConfiguration(
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      outlineEnabled: outlineEnabled ?? this.outlineEnabled,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineSize: outlineSize ?? this.outlineSize,
      fontFamily: fontFamily ?? this.fontFamily,
      leftPadding: leftPadding ?? this.leftPadding,
      rightPadding: rightPadding ?? this.rightPadding,
      bottomPadding: bottomPadding ?? this.bottomPadding,
      alignment: alignment ?? this.alignment,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textAlign: textAlign ?? this.textAlign,
    );
  }
}
