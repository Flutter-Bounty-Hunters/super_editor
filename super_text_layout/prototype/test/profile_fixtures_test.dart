import 'package:flutter_test/flutter_test.dart';
import 'package:flow_layout_prototype/profile_fixture_data.dart';

void main() {
  test('v4 retains all five workloads', () {
    expect(
        profileFixtureMetadata.keys,
        containsAll(
            ['test_boxes', 'demo_buttons', 'unique_prose', 'decorated_code']));
    for (final name in profileFixtureMetadata.keys) {
      if (name == 'long_prose') {
        expect(profileFixtureChunks[name], hasLength(1));
        expect(profileFixtureChunks[name]!.single.length, 1000);
        continue;
      }
      expect(profileFixtureChunks[name], hasLength(100));
      expect(profileFixtureChunks[name]!.every((s) => s.length == 100), isTrue);
    }
    expect(profileFixtureChunks['unique_prose']!.toSet(), hasLength(100));
    expect(profileFixtureChunks['decorated_code']!.toSet(), hasLength(100));
    expect(profileFixtureChunks['test_boxes']!.toSet(), hasLength(1));
  });
  test('all three edits insert exactly once at distinct locations', () {
    expect(profilePhases.skip(2),
        orderedEquals(ProfileEdit.values.map((e) => e.phase)));
    for (final scenario in profileFixtureMetadata.keys) {
      final chunks = profileFixtureChunks[scenario]!;
      final original = chunks.join();
      final positions = <int>[];
      for (final edit in ProfileEdit.values) {
        final location = profileEditLocation(scenario, edit);
        final global =
            chunks.take(location.chunk).fold(0, (n, text) => n + text.length) +
                location.offset;
        positions.add(global);
        final edited = [
          for (var i = 0; i < chunks.length; i++)
            profileChunkText(scenario, i, edit)
        ].join();
        expect(edited,
            '${original.substring(0, global)}changed${original.substring(global)}');
        expect(edited.length, original.length + 7);
      }
      expect(positions,
          scenario == 'long_prose' ? [0, 500, 1000] : [0, 5050, 10000]);
    }
  });
  test('code insertions preserve head, inner span, and tail ownership', () {
    for (final edit in ProfileEdit.values) {
      final location = profileEditLocation('decorated_code', edit);
      final i = location.chunk;
      final original = profileFixtureChunks['decorated_code']![i];
      final head = profileChunkText('decorated_code', i, edit, end: 12);
      final body =
          profileChunkText('decorated_code', i, edit, start: 12, end: 76);
      final tail = profileChunkText('decorated_code', i, edit, start: 76);
      expect(head + body + tail, profileChunkText('decorated_code', i, edit));
      expect(
          head,
          edit == ProfileEdit.beginning
              ? 'changed${original.substring(0, 12)}'
              : original.substring(0, 12));
      expect(body.length, edit == ProfileEdit.middle ? 71 : 64);
      expect(
          tail,
          edit == ProfileEdit.end
              ? '${original.substring(76)}changed'
              : original.substring(76));
    }
  });
}
