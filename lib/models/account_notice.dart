class AccountNotice {
  const AccountNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String content;
  final DateTime? updatedAt;

  factory AccountNotice.fromJson(Map<String, dynamic> json) {
    return AccountNotice(
      id: _toInt(json['id']),
      title: _plainText(json['title'], maximumLength: 100),
      content: _plainText(json['content'], maximumLength: 3000),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  bool get isVisible => title.isNotEmpty || content.isNotEmpty;
}

String _plainText(dynamic value, {required int maximumLength}) {
  if (value is! String || value.trim().isEmpty) return '';
  final boundedValue = value.length > 12000 ? value.substring(0, 12000) : value;
  var text = boundedValue
      .replaceAll(
          RegExp(r'<(script|style)[^>]*>.*?</\1>',
              caseSensitive: false, dotAll: true),
          '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (text.length > maximumLength) {
    text = '${text.substring(0, maximumLength).trimRight()}…';
  }
  return text;
}

DateTime? _dateTime(dynamic value) {
  if (value == null) return null;
  final seconds = _toInt(value);
  if (seconds > 0) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .toLocal();
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
