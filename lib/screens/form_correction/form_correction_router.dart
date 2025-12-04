import 'package:flutter/material.dart';
import 'package:perfit/screens/form_correction/barbell_row.dart';
import 'package:perfit/screens/form_correction/crunches.dart';
import 'package:perfit/screens/form_correction/curl_up_screen.dart';
import 'package:perfit/screens/form_correction/deadlift_screen.dart';
import 'package:perfit/screens/form_correction/knee_extension_seated_partial_screen.dart';
import 'package:perfit/screens/form_correction/plank_screen.dart';
import 'package:perfit/screens/form_correction/push_up_screen.dart';
import 'package:perfit/screens/form_correction/split_squat_screen.dart';
import 'package:perfit/screens/form_correction/squats_screen.dart';

//nyah nicole
class FormCorrectionRouter {
  static final Map<String, Widget Function()> routes = {
    "barbell_curl": () => CurlUpScreen(),
    "knee_extension_seated_partial": () => KneeExtensionSeatedPartialScreen(),
    "push_up": () => PushUpScreen(),
    "bodyweight_squat": () => SquatsScreen(),
    "barbell_bent_over_row": () => BarbellRowScreen(),
    "split_squat": () => SplitSquatScreen(),
    // "barbell_bench_press": () => BenchPressFormCorrection(),
    // "barbell_deadlift": () => DeadliftFormCorrection(),
  };

  static Widget? getScreen(String exerciseId) {
    if (routes.containsKey(exerciseId)) {
      return routes[exerciseId]!();
    }
    return null;
  }
}
