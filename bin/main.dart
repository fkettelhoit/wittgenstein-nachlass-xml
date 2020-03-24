import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:html/parser.dart' as html;

void main(List<String> arguments) => _fetchNachlass();

final String _wabOAUrl = 'http://wab.uib.no/cost-a32_xml/';

Future<void> _fetchNachlass() async {
  final docs = await _fetchXmlNames(_wabOAUrl);
  await Future.wait(docs.map(_fetchDocument).map(_formatDocument));
}

Future<io.File> _fetchDocument(String name, {bool skipExisting = false}) async {
  final blacklist = {
    'Ms-140,39v_OA.xml',
    'Ts-212%20renamed_OA.xml',
    'Ts-246_OA.xml',
    'Ts-309-Stonborough_OA.xml',
    'Ts-310-Redpath_OA.xml'
  };
  if (blacklist.contains(name)) return null;

  final file = io.File('xml/$name');
  if (skipExisting && await file.existsSync()) {
    print('$name already exists, skipping download');
    return null;
  }
  print('fetching $name');
  await io.HttpClient()
      .getUrl(Uri.parse('$_wabOAUrl$name'))
      .then((request) => request.close())
      .then<dynamic>((response) => response.pipe(file.openWrite()));
  return file;
}

Future<void> _formatDocument(Future<io.File> file) async {
  final f = await file;
  if (f == null) return;

  final content = await f.readAsString();
  final zeroWidthSpace = '\u200B';
  final onlySpaces = content
      .replaceAll(RegExp(r'[\n\t\r]'), ' ')
      .replaceAll(zeroWidthSpace, '');
  await f.writeAsString(onlySpaces);
  return io.Process.run('xmllint', ['--format', f.path]).then((result) {
    f.writeAsString(result.stdout.toString());
  });
}

Future<List<String>> _fetchXmlNames(String url) async {
  final fetched = await _fetchHtml(url);
  final doc = html.parse(fetched);
  return doc
      .getElementsByTagName('a')
      .where((a) =>
          a.text.endsWith('.xml') &&
          !a.text.contains('missing') &&
          !a.text.startsWith('LPA'))
      .map((a) => a.attributes['href'])
      .toList();
}

Future<String> _fetchHtml(String uri) => io.HttpClient()
    .getUrl(Uri.parse(uri))
    .then((request) => request.close())
    .then<String>(_readResponse);

Future<String> _readResponse(io.HttpClientResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.transform(utf8.decoder).listen(contents.write,
      onDone: () => completer.complete(contents.toString()));
  return completer.future;
}
