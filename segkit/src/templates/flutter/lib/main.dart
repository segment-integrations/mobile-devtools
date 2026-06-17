import 'package:flutter/material.dart';
import 'package:segment_analytics/analytics.dart';
import 'package:segment_analytics/client.dart';
import 'package:segment_analytics/state.dart';
import 'config.dart';
import 'console_logger_plugin.dart';
__PLUGIN_IMPORTS__
late Analytics analytics;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  analytics = createClient(Configuration(Config.segmentWriteKey, __DEBUG_FLAG__));
  analytics.addPlugin(ConsoleLoggerPlugin());
__PLUGIN_ADDS__
  debugPrint('Segment Analytics initialized');
  debugPrint('  Write Key: ${Config.segmentWriteKey}');
  debugPrint('  Mode: ${Config.isUsingDemoKey ? "Demo (events queued locally)" : "Live (sending to Segment)"}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Segment Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tracked = 0;
  int _inQueue = 0;
  int _sent = 0;
  bool _isManualFlush = false;
__TOGGLE_STATES__
  void _record() {
    setState(() {
      _tracked++;
      if (_isManualFlush) {
        _inQueue++;
      } else {
        _sent++;
      }
    });
  }

  void _flush() {
    analytics.flush();
    setState(() {
      _sent += _inQueue;
      _inQueue = 0;
    });
  }

  void _trackEvent() {
    _record();
    analytics.track('Button Pressed', properties: {
      'button': 'Track Event',
      'count': _tracked,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _identifyUser() {
    _record();
    analytics.identify(userId: 'demo-user');
  }

  void _trackScreen() {
    _record();
    analytics.screen('Demo Screen', properties: {
      'screen_name': 'HomePage',
      'view_count': _tracked,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.show_chart, size: 60, color: Colors.blue),
              const SizedBox(height: 8),
              const Text(
                'Segment Flutter Demo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Analytics Flutter SDK',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (Config.isUsingDemoKey)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demo mode',
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {}),
                      child: Text(
                        'Recheck',
                        style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              Row(children: [
                _StatCard(value: _tracked, label: 'Tracked', color: Colors.blue),
                const SizedBox(width: 12),
                _StatCard(value: _inQueue, label: 'In Queue', color: Colors.orange),
                const SizedBox(width: 12),
                _StatCard(value: _sent, label: 'Sent', color: Colors.green),
              ]),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _trackEvent,
                icon: const Icon(Icons.bar_chart),
                label: const Text('Track Event'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _identifyUser,
                icon: const Icon(Icons.person),
                label: const Text('Identify User'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _trackScreen,
                icon: const Icon(Icons.phone_iphone),
                label: const Text('Track Screen'),
                style: FilledButton.styleFrom(backgroundColor: Colors.purple),
              ),
              const SizedBox(height: 24),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Flush Mode',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Auto')),
                      ButtonSegment(value: true, label: Text('Manual')),
                    ],
                    selected: {_isManualFlush},
                    onSelectionChanged: (s) => setState(() => _isManualFlush = s.first),
                  ),
                ],
              ),
              if (_isManualFlush) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _inQueue > 0 ? _flush : null,
                  icon: const Icon(Icons.upload),
                  label: Text('Flush Now ($_inQueue queued)'),
                ),
              ],
__TOGGLE_SECTION__
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginRow extends StatelessWidget {
  final String name;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PluginRow({required this.name, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(
            enabled ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: enabled ? Colors.blue : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 15))),
          Text(
            'Available',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }
}
