import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/strings.dart';

void main() {
  group("Strings", () {
    group("find upstream", () {
      test("1 character", () {
        expect("a💙c".moveOffsetUpstreamByCharacter(0), null);
        expect("a💙c".moveOffsetUpstreamByCharacter(1), 0);
        expect("a💙c".moveOffsetUpstreamByCharacter(3), 1);
        expect("a💙c".moveOffsetUpstreamByCharacter(4), 3);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(-1), throwsException);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(5), throwsException);
      });

      test("2 characters", () {
        expect("a💙c".moveOffsetUpstreamByCharacter(0, characterCount: 2), null);
        expect("a💙c".moveOffsetUpstreamByCharacter(1, characterCount: 2), null);
        expect("a💙c".moveOffsetUpstreamByCharacter(3, characterCount: 2), 0);
        expect("a💙c".moveOffsetUpstreamByCharacter(4, characterCount: 2), 1);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(-1, characterCount: 2), throwsException);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(5, characterCount: 2), throwsException);
      });

      test("a word", () {
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(18), 15);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(16), 15);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(15), 12);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(14), 12);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(12), 7);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(11), 7);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(10), 7);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(7), 2);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(6), 2);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(2), 0);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(1), 0);
        expect("  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(0), null);
        expect(() => "  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(-1), throwsException);
        expect(() => "  move a💙c\u3000wo.rds".moveOffsetUpstreamByWord(19), throwsException);
      });
    });

    group("find downstream", () {
      test("1 character", () {
        expect("a💙c".moveOffsetDownstreamByCharacter(0), 1);
        expect("a💙c".moveOffsetDownstreamByCharacter(1), 3);
        expect("a💙c".moveOffsetDownstreamByCharacter(3), 4);
        expect("a💙c".moveOffsetDownstreamByCharacter(4), null);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(-1), throwsException);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(5), throwsException);
      });

      test("2 characters", () {
        expect("a💙c".moveOffsetDownstreamByCharacter(0, characterCount: 2), 3);
        expect("a💙c".moveOffsetDownstreamByCharacter(1, characterCount: 2), 4);
        expect("a💙c".moveOffsetDownstreamByCharacter(3, characterCount: 2), null);
        expect("a💙c".moveOffsetDownstreamByCharacter(4, characterCount: 2), null);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(-1, characterCount: 2), throwsException);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(5, characterCount: 2), throwsException);
      });

      test("a word", () {
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(0), 4);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(4), 9);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(5), 9);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(6), 9);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(8), 9);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(9), 12);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(10), 12);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(12), 16);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(16), 18);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(17), 18);
        expect("move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(18), null);
        expect(() => "move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(-1), throwsException);
        expect(() => "move a💙c\u3000wo.rds  ".moveOffsetDownstreamByWord(19), throwsException);
      });
    });
  });
}
