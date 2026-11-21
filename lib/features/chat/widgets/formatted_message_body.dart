import 'package:flutter/material.dart';
import '../../../app/theme/theme_provider.dart';

/// Renders AI markdown responses cleanly on mobile:
/// - Headings (#, ##, ###)
/// - Inline **bold**, *italic*, and `code`
/// - Bulleted (- / *) and numbered (1.) lists
/// - Clean bordered scrollable tables instead of raw `|---|---|` pipes
/// - Fenced code blocks (```)
class FormattedMessageBody extends StatelessWidget {
  final String text;
  final Color textColor;

  const FormattedMessageBody({
    super.key,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(blocks.length, (i) {
        final isLast = i == blocks.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
          child: _buildBlock(context, blocks[i]),
        );
      }),
    );
  }

  Widget _buildBlock(BuildContext context, _MdBlock block) {
    switch (block.kind) {
      case _BlockKind.heading:
        final fontSize = block.level == 1 ? 17.0 : (block.level == 2 ? 15.5 : 14.5);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text.rich(
            _parseInlineSpans(
              block.text,
              TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.35,
              ),
              context,
            ),
          ),
        );

      case _BlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  _parseInlineSpans(
                    block.text,
                    TextStyle(fontSize: 14.5, height: 1.45, color: textColor),
                    context,
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockKind.numbered:
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${block.prefix}.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.accentColor,
                    height: 1.45,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  _parseInlineSpans(
                    block.text,
                    TextStyle(fontSize: 14.5, height: 1.45, color: textColor),
                    context,
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.borderColor),
          ),
          child: SelectableText(
            block.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.4,
              color: textColor,
            ),
          ),
        );

      case _BlockKind.table:
        return _buildTable(context, block.rows);

      case _BlockKind.paragraph:
        return Text.rich(
          _parseInlineSpans(
            block.text,
            TextStyle(fontSize: 14.5, height: 1.48, color: textColor),
            context,
          ),
        );
    }
  }

  Widget _buildTable(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final headers = rows.first;
    final dataRows = rows.skip(1).toList();

    // If only header row or simple 1-row table, render a single card
    if (dataRows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: headers.map((h) => Text.rich(_parseInlineSpans(h, TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor), context))).toList(),
        ),
      );
    }

    // Convert table rows into readable mobile-native concept cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: dataRows.map((r) {
        final title = r.isNotEmpty ? r[0] : '';
        final details = r.length > 1 ? r.sublist(1) : <String>[];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: BoxDecoration(
                        color: context.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        _parseInlineSpans(
                          title,
                          TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: context.accentColor,
                            height: 1.35,
                          ),
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              ...List.generate(details.length, (idx) {
                final colIdx = idx + 1;
                final headerLabel = colIdx < headers.length ? headers[colIdx] : '';
                final value = details[idx];

                return Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 2, left: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (headerLabel.isNotEmpty)
                        Text(
                          headerLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: context.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 1),
                      Text.rich(
                        _parseInlineSpans(
                          value,
                          TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: textColor,
                          ),
                          context,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  TextSpan _parseInlineSpans(String input, TextStyle baseStyle, BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    int lastEnd = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: input.substring(lastEnd, match.start), style: baseStyle));
      }
      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (token.startsWith('*') && token.endsWith('*') && token.length > 2) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('`') && token.endsWith('`') && token.length > 2) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 14) - 1,
            backgroundColor: context.borderColor.withOpacity(0.45),
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      spans.add(TextSpan(text: input.substring(lastEnd), style: baseStyle));
    }
    return TextSpan(children: spans.isEmpty ? [TextSpan(text: input, style: baseStyle)] : spans);
  }

  List<_MdBlock> _parseBlocks(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_MdBlock>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }

      // Fenced code block
      if (line.startsWith('```')) {
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        i++;
        blocks.add(_MdBlock(_BlockKind.code, text: codeLines.join('\n')));
        continue;
      }

      // Markdown table block
      if (line.startsWith('|') && line.contains('|', 1)) {
        final rows = <List<String>>[];
        while (i < lines.length) {
          final currentLine = lines[i].trim();
          if (currentLine.isEmpty) break;
          if (currentLine.startsWith('|')) {
            final isSeparator = RegExp(r'^\|[\s\-:|]+\|$').hasMatch(currentLine);
            if (!isSeparator) {
              final cells = currentLine
                  .split('|')
                  .map((c) => c.trim())
                  .where((c) => c.isNotEmpty)
                  .toList();
              if (cells.isNotEmpty) rows.add(cells);
            }
            i++;
          } else if (rows.isNotEmpty &&
              !currentLine.startsWith('#') &&
              !currentLine.startsWith('-') &&
              !currentLine.startsWith('*') &&
              !currentLine.startsWith('```')) {
            // Multiline cell continuation from previous row
            final lastRow = rows.last;
            if (lastRow.isNotEmpty) {
              lastRow[lastRow.length - 1] = '${lastRow.last} $currentLine';
            }
            i++;
          } else {
            break;
          }
        }
        if (rows.isNotEmpty) {
          blocks.add(_MdBlock(_BlockKind.table, rows: rows));
        }
        continue;
      }

      // Headings
      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        blocks.add(_MdBlock(
          _BlockKind.heading,
          level: headingMatch.group(1)!.length,
          text: headingMatch.group(2)!.trim(),
        ));
        i++;
        continue;
      }

      // Bullets
      if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ')) {
        blocks.add(_MdBlock(_BlockKind.bullet, text: line.substring(2).trim()));
        i++;
        continue;
      }

      // Numbered list
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(line);
      if (numMatch != null) {
        blocks.add(_MdBlock(
          _BlockKind.numbered,
          prefix: numMatch.group(1)!,
          text: numMatch.group(2)!.trim(),
        ));
        i++;
        continue;
      }

      // Paragraph
      blocks.add(_MdBlock(_BlockKind.paragraph, text: line));
      i++;
    }

    return blocks;
  }
}

enum _BlockKind { heading, bullet, numbered, code, table, paragraph }

class _MdBlock {
  final _BlockKind kind;
  final String text;
  final String prefix;
  final int level;
  final List<List<String>> rows;

  _MdBlock(
    this.kind, {
    this.text = '',
    this.prefix = '',
    this.level = 2,
    this.rows = const [],
  });
}
