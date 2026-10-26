import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'geometry.dart';
part 'participants.dart';
part 'paragraph.dart';
part 'measurement.dart';
part 'text_backend.dart';
part 'text_shape_cache.dart';
part 'text_choice_cache.dart';
part 'text_width_cache.dart';
part 'unicode/line_break.dart';
part 'unicode/line_break_data.dart';

// Opt-in CPU attribution only. Constant false removes tagging from normal builds.
const _profileFlow = bool.fromEnvironment('FLOW_PROFILE_LAYOUT');
final _flowLayoutTag = developer.UserTag('Flow.layout');
final _flowChildrenTag = developer.UserTag('Flow.children');
final _flowPrepareTag = developer.UserTag('Flow.prepare');
final _flowAttemptTag = developer.UserTag('Flow.firstAttempt');
final _flowRetryTag = developer.UserTag('Flow.heightRetry');
