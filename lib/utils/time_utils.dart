DateTime addTimeOffset(DateTime date) {
  return date.add(const Duration(hours: 5, minutes: 30));
}

DateTime subtractTimeOffset(DateTime date) {
  return date.subtract(const Duration(hours: 5, minutes: 30));
}