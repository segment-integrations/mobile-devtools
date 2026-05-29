export const Config = {
  segmentWriteKey: 'demo_write_key_not_real',

  get isUsingDemoKey(): boolean {
    return (
      !this.segmentWriteKey ||
      this.segmentWriteKey === 'demo_write_key_not_real' ||
      this.segmentWriteKey === 'YOUR_WRITE_KEY_HERE'
    );
  },
};
