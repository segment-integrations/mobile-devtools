import 'package:flutter/foundation.dart';
import 'package:segment_analytics/event.dart';
import 'package:segment_analytics/plugin.dart';

class ConsoleLoggerPlugin extends Plugin {
  ConsoleLoggerPlugin() : super(PluginType.enrichment);

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    final typeName = event.type.toString().split('.').last.toUpperCase();
    final name = event is TrackEvent ? ' (${event.event})' : '';
    debugPrint('[Segment] $typeName$name');
    return event;
  }
}
