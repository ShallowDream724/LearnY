import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/urls.dart' as urls;

enum SsoNavigationKind { allow, consumeTicket }

class SsoNavigationInstruction {
  const SsoNavigationInstruction._({required this.kind, this.ticket});

  const SsoNavigationInstruction.allow()
    : this._(kind: SsoNavigationKind.allow);

  const SsoNavigationInstruction.consumeTicket(String ticket)
    : this._(kind: SsoNavigationKind.consumeTicket, ticket: ticket);

  final SsoNavigationKind kind;
  final String? ticket;

  bool get shouldConsumeTicket => kind == SsoNavigationKind.consumeTicket;
}

class SsoTicketParser {
  const SsoTicketParser();

  SsoNavigationInstruction inspectNavigation(String url) {
    final uri = Uri.tryParse(url);
    final ticket = uri?.queryParameters['ticket'];
    if (ticket == null || ticket.isEmpty) {
      return const SsoNavigationInstruction.allow();
    }

    if (url.contains('j_spring_security_thauth_roaming_entry')) {
      return SsoNavigationInstruction.consumeTicket(ticket);
    }

    return const SsoNavigationInstruction.allow();
  }

  bool shouldAttemptFallback(String url) {
    return url.startsWith(urls.learnPrefix) &&
        !url.contains('j_spring_security_thauth_roaming_entry');
  }
}

final ssoTicketParserProvider = Provider<SsoTicketParser>((ref) {
  return const SsoTicketParser();
});
