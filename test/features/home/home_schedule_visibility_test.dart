import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/auth_controller.dart';
import 'package:learn_y/features/home/widgets/home_sections.dart';

void main() {
  test('cached auth state still shows the home schedule section', () {
    expect(
      shouldShowHomeTodayScheduleSection(
        const AuthState.cached(username: '静昱鸣'),
      ),
      isTrue,
    );
  });

  test('signed-out auth state hides the home schedule section', () {
    expect(
      shouldShowHomeTodayScheduleSection(const AuthState.signedOut()),
      isFalse,
    );
  });
}
