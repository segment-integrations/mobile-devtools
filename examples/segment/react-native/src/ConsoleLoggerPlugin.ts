import {
  DestinationPlugin,
  PluginType,
  SegmentEvent,
} from '@segment/analytics-react-native';

export class ConsoleLoggerPlugin extends DestinationPlugin {
  type = PluginType.destination;
  key = 'ConsoleLogger';

  execute(event: SegmentEvent): SegmentEvent {
    const type = event.type?.toUpperCase() ?? 'UNKNOWN';
    const timestamp = new Date().toISOString();

    console.log(`\n[ConsoleLogger] ${type} @ ${timestamp}`);
    console.log(JSON.stringify(event, null, 2));

    return event;
  }
}
