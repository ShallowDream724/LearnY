import 'package:flutter/material.dart';

import '../../../core/auth/auth_entry_models.dart';
import '../../auth/widgets/identity_auth_flow_screen.dart';

class AutoReloginEnrollmentScreen extends StatelessWidget {
  const AutoReloginEnrollmentScreen({super.key, required this.input});

  final AutoReloginSetupInput input;

  @override
  Widget build(BuildContext context) {
    return IdentityAuthFlowScreen(
      request: AuthEntryRequest.enableAutoRelogin(input: input),
    );
  }
}
