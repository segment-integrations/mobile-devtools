class Config {
  static const segmentWriteKey = '__WRITE_KEY__';

  static bool get isUsingDemoKey =>
      segmentWriteKey.isEmpty ||
      segmentWriteKey == 'demo_write_key_not_real' ||
      segmentWriteKey == 'YOUR_WRITE_KEY_HERE';
}
