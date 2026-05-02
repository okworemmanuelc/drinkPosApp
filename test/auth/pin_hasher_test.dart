import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/shared/services/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('correct PIN verifies, wrong PIN rejects', () {
      final salt = PinHasher.generateSaltBase64();
      const iterations = PinHasher.defaultIterations;
      final hash = PinHasher.hashBase64('123456', salt, iterations);

      final correct = PinHasher.hashBase64('123456', salt, iterations);
      final wrong = PinHasher.hashBase64('654321', salt, iterations);

      expect(PinHasher.constantTimeEquals(hash, correct), isTrue);
      expect(PinHasher.constantTimeEquals(hash, wrong), isFalse);
    });

    test('different salts produce different hashes for same PIN', () {
      final saltA = PinHasher.generateSaltBase64();
      final saltB = PinHasher.generateSaltBase64();
      const iterations = PinHasher.defaultIterations;

      expect(saltA, isNot(equals(saltB)));

      final hashA = PinHasher.hashBase64('123456', saltA, iterations);
      final hashB = PinHasher.hashBase64('123456', saltB, iterations);

      expect(hashA, isNot(equals(hashB)));
    });

    test('default iteration count is at least 100k', () {
      expect(PinHasher.defaultIterations, greaterThanOrEqualTo(100000));
    });
  });
}
