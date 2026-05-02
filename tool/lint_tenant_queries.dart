// ignore_for_file: avoid_print
import 'dart:io';
import 'tenant_tables.dart';

/// A simple lint tool to ensure all queries to tenant-scoped tables
/// include a businessId filter.
///
/// Usage: dart tool/lint_tenant_queries.dart
void main() {
  final daosFile = File('lib/core/database/daos.dart');
  if (!daosFile.existsSync()) {
    print('Error: daos.dart not found');
    exit(1);
  }

  final content = daosFile.readAsStringSync();
  int errors = 0;

  // We look for select(table), update(table), or delete(table)
  // Using dotAll: true to match across lines
  final queryRegex = RegExp(r'(select|update|delete)\s*\(\s*([^)]+)\s*\)', dotAll: true);
  
  final matches = queryRegex.allMatches(content);

  for (final match in matches) {
    var table = match.group(2)!.trim();
    if (table.endsWith(',')) table = table.substring(0, table.length - 1).trim();
    
    if (tenantTables.contains(table)) {
      final startIndex = match.start;
      
      // Find method start (previous \n   followed by non-space)
      final methodStartRegex = RegExp(r'\n  [^\s]');
      final previousMethodMatches = methodStartRegex.allMatches(content.substring(0, startIndex));
      int methodStart = previousMethodMatches.isEmpty ? 0 : previousMethodMatches.last.start;
      
      // Find method end (next \n   followed by non-space)
      final nextMethodMatch = methodStartRegex.firstMatch(content.substring(startIndex));
      int methodEnd = nextMethodMatch == null ? content.length : startIndex + nextMethodMatch.start;
      
      final snippet = content.substring(methodStart, methodEnd);
      
      if (!snippet.contains('businessId.equals') && 
          !snippet.contains('requireBusinessId()') &&
          !snippet.contains('whereBusiness') &&
          !snippet.contains('deliberately not businessId-scoped')) {
        
        final lineNumber = content.substring(0, startIndex).split('\n').length;
        print('Error: Tenant table "$table" query missing businessId filter at line $lineNumber');
        print('  ${match.group(0)!.replaceAll('\n', ' ').trim()}');
        errors++;
      }
    }
  }

  if (errors > 0) {
    print('\nFound $errors tenant leakage issues.');
    exit(1);
  } else {
    print('All tenant queries verified.');
  }
}
