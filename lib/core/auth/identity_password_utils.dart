final RegExp _identityCiphertextPattern = RegExp(r'^04[0-9a-fA-F]{128,}$');

bool looksLikeIdentityPasswordCiphertext(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  return _identityCiphertextPattern.hasMatch(normalized);
}

String resolveEnrollmentPassword({
  required String submittedPassword,
  required String fallbackPassword,
}) {
  final normalized = submittedPassword.trim();
  if (normalized.isEmpty) {
    return fallbackPassword;
  }
  if (looksLikeIdentityPasswordCiphertext(normalized)) {
    return fallbackPassword;
  }
  return submittedPassword;
}
