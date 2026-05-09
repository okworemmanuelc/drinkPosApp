import 'dart:io';
import 'dart:isolate';

void main() async {
  final uri = Uri.parse('package:gotrue/src/gotrue_client.dart');
  final resolved = await Isolate.resolvePackageUri(uri);
  if (resolved == null) {
    print('Could not resolve package:gotrue');
    return;
  }
  print('Resolved path: $resolved');
  final lines = await File.fromUri(resolved).readAsLines();
  for (var i = 430; i < 480 && i < lines.length; i++) {
    print('${i + 1}: ${lines[i]}');
  }
}
