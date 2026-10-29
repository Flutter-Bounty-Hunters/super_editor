/// Versioned, deterministic fixture inputs shared by the app and baseline gate.
const profileFixtureVersion = 4;
const profileFixtureMetadata = <String, Map<String, Object>>{
  'test_boxes': {
    'textCharacters': 10000,
    'inlineWidgets': 100,
    'fontSize': 20,
    'obstacle': false
  },
  'demo_buttons': {
    'textCharacters': 10000,
    'inlineWidgets': 100,
    'fontSize': 18,
    'obstacle': true
  },
  'long_prose': {
    'textCharacters': 1000,
    'inlineWidgets': 0,
    'fontSize': 20,
    'obstacle': false
  },
  'unique_prose': {
    'textCharacters': 10000,
    'inlineWidgets': 100,
    'fontSize': 20,
    'obstacle': false
  },
  'decorated_code': {
    'textCharacters': 10000,
    'inlineWidgets': 100,
    'fontSize': 18,
    'obstacle': true,
    'decorations': 200
  },
};

final profileFixtureChunks = <String, List<String>>{
  for (final name in profileFixtureMetadata.keys)
    name: name == 'long_prose'
        ? List.unmodifiable(
            [List.generate(10, (i) => _chunk('unique_prose', i)).join()])
        : List.unmodifiable(List.generate(100, (i) => _chunk(name, i))),
};

String _chunk(String name, int i) {
  if (name == 'test_boxes') {
    return ('a short sentence with enough spaces to wrap. ' * 3)
        .substring(0, 100);
  }
  if (name == 'demo_buttons') {
    return ('A paragraph with fragmentable inline content and ordinary widgets. ' *
            2)
        .substring(0, 100);
  }
  if (name == 'decorated_code') {
    return ('final result$i = entries.where((item) => item.rank > ${i * 7}).map((item) => item.label).toList(); // inspect batch $i carefully. ')
        .substring(0, 100);
  }
  const places = [
    'harbor',
    'woodland',
    'station',
    'garden',
    'workshop',
    'library',
    'courtyard',
    'hillside',
    'market',
    'riverbank'
  ];
  const people = [
    'engineer',
    'traveler',
    'gardener',
    'teacher',
    'painter',
    'historian',
    'builder',
    'scientist',
    'librarian',
    'musician'
  ];
  const actions = [
    'studied the changing light',
    'recorded a surprising observation',
    'compared the earlier notes',
    'described an unfamiliar pattern',
    'prepared a careful explanation'
  ];
  return ('At the ${places[i % places.length]}, a ${people[i ~/ 10]} ${actions[i % actions.length]}. '
          'The account from visit ${i + 1} explains how small details shaped the next decision. ')
      .substring(0, 100);
}

const profilePhases = [
  'initial',
  'resize',
  'edit_beginning',
  'edit_middle',
  'edit_end'
];
const profileEditText = 'changed';
const profileEditSetup =
    'Each edit independently starts with a fresh paragraph at width 600, then resizes to 320 before inserting 7 characters.';

enum ProfileEdit {
  beginning('edit_beginning'),
  middle('edit_middle'),
  end('edit_end');

  const ProfileEdit(this.phase);
  final String phase;
}

({int chunk, int offset}) profileEditLocation(
    String scenario, ProfileEdit edit) {
  final chunks = profileFixtureChunks[scenario]!;
  return switch (edit) {
    ProfileEdit.beginning => (chunk: 0, offset: 0),
    ProfileEdit.middle => (
        chunk: chunks.length ~/ 2,
        offset: chunks[chunks.length ~/ 2].length ~/ 2
      ),
    ProfileEdit.end => (chunk: chunks.length - 1, offset: chunks.last.length),
  };
}

/// Extract one original styled segment, applying an insertion only to its owner.
/// Original style boundaries stay attached to their original text. For example,
/// an insertion in the inner code span does not shift trailing text into it.
String profileChunkText(String scenario, int chunk, ProfileEdit? edit,
    {int start = 0, int? end}) {
  final text = profileFixtureChunks[scenario]![chunk];
  final limit = end ?? text.length;
  final segment = text.substring(start, limit);
  if (edit == null) return segment;
  final location = profileEditLocation(scenario, edit);
  if (location.chunk != chunk ||
      location.offset < start ||
      (location.offset >= limit &&
          !(location.offset == text.length && limit == text.length))) {
    return segment;
  }
  final at = location.offset - start;
  return segment.substring(0, at) + profileEditText + segment.substring(at);
}
