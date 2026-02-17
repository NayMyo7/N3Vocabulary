import 'package:flutter/material.dart';

class FuriganaText extends StatelessWidget {
  const FuriganaText(
    this.text, {
    super.key,
    this.baseStyle,
    this.furiganaStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? baseStyle;
  final TextStyle? furiganaStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  // Cache for parsed tokens to avoid repeated parsing
  static final Map<String, List<_FuriganaToken>> _tokenCache = {};

  @override
  Widget build(BuildContext context) {
    final defaultBaseStyle = DefaultTextStyle.of(context).style;
    final base = baseStyle ?? defaultBaseStyle;
    final baseFontSize = (base.fontSize ?? 14).toDouble();
    final ruby = furiganaStyle ??
        base.copyWith(
          fontSize: baseFontSize * 0.5,
          height: 1.0,
        );

    // Use cached tokens if available
    final tokens = _tokenCache.putIfAbsent(text, () => _parse(text));
    final hasRuby = tokens.any(
      (t) => t.reading != null && t.reading!.isNotEmpty,
    );
    if (!hasRuby) {
      return Text(
        text,
        style: base,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Split text by line breaks and process each line separately
    final lines = text.split('\n');
    final lineWidgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final lineText = lines[i];
      if (lineText.isEmpty) {
        // Add empty line for blank lines
        lineWidgets.add(SizedBox(height: baseFontSize * 1.2));
        continue;
      }

      final lineTokens =
          _tokenCache.putIfAbsent(lineText, () => _parse(lineText));
      final tokenWidgets = <Widget>[];

      for (final token in lineTokens) {
        final baseText = token.base;
        final rubyText = token.reading;

        final baseWidth = _measureTextWidth(baseText, base);
        final rubyWidth =
            rubyText == null ? 0.0 : _measureTextWidth(rubyText, ruby);
        final w = (baseWidth > rubyWidth ? baseWidth : rubyWidth);

        tokenWidgets.add(
          SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (rubyText != null)
                  Text(
                    rubyText,
                    style: ruby,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    textAlign: TextAlign.center,
                  )
                else
                  SizedBox(
                    height: (ruby.fontSize ?? baseFontSize * 0.5) * 1.2,
                  ),
                Text(
                  baseText,
                  style: base.copyWith(height: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      lineWidgets.add(
        Wrap(
          alignment: _wrapAlignment(textAlign),
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 0,
          runSpacing: 0,
          children: tokenWidgets,
        ),
      );

      // Add spacing between lines (except for the last line)
      if (i < lines.length - 1) {
        lineWidgets.add(SizedBox(height: baseFontSize * 0.5));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lineWidgets,
    );
  }
}

double _measureTextWidth(String text, TextStyle style) {
  if (text.isEmpty) return 0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.size.width;
}

WrapAlignment _wrapAlignment(TextAlign? textAlign) {
  switch (textAlign) {
    case TextAlign.center:
      return WrapAlignment.center;
    case TextAlign.end:
    case TextAlign.right:
      return WrapAlignment.end;
    default:
      return WrapAlignment.start;
  }
}

class _FuriganaToken {
  const _FuriganaToken({required this.base, this.reading});

  final String base;
  final String? reading;
}

List<_FuriganaToken> _parse(String input) {
  // Format: "{漢字;かんじ}" mixed with plain text.
  // We keep behavior similar to Android FuriganaView markup.
  final tokens = <_FuriganaToken>[];

  var text = input;
  while (text.isNotEmpty) {
    final open = text.indexOf('{');
    if (open < 0) {
      tokens.add(_FuriganaToken(base: text));
      break;
    }

    if (open > 0) {
      tokens.add(_FuriganaToken(base: text.substring(0, open)));
      text = text.substring(open);
    }

    final close = text.indexOf('}');
    if (close < 0) {
      // Unbalanced, treat rest as plain.
      tokens.add(_FuriganaToken(base: text));
      break;
    }

    final inner = text.substring(1, close);
    final parts = inner.split(';');
    final base = parts.isNotEmpty ? parts[0] : '';
    final reading = parts.length >= 2 ? parts[1] : null;

    if (base.isNotEmpty) {
      tokens.add(
        _FuriganaToken(
          base: base,
          reading: (reading?.isEmpty ?? true) ? null : reading,
        ),
      );
    }

    text = text.substring(close + 1);
  }

  return tokens;
}
