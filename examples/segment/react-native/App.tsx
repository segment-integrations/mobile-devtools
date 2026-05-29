import React, {useEffect, useRef, useState} from 'react';
import {
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  createClient,
  SegmentClient,
} from '@segment/analytics-react-native';
import {Config} from './src/Config';
import {ConsoleLoggerPlugin} from './src/ConsoleLoggerPlugin';

export default function App() {
  const [eventCount, setEventCount] = useState(0);
  const [lastEventTime, setLastEventTime] = useState<string | null>(null);
  const clientRef = useRef<SegmentClient | null>(null);

  useEffect(() => {
    const client = createClient({
      writeKey: Config.segmentWriteKey,
      trackAppLifecycleEvents: true,
      flushAt: Config.isUsingDemoKey ? 1000 : 20,
      flushInterval: Config.isUsingDemoKey ? 0 : 30,
    });

    client.add({plugin: new ConsoleLoggerPlugin()});
    clientRef.current = client;

    console.log('Segment Analytics initialized');
    console.log(`  Write Key: ${Config.segmentWriteKey}`);
    console.log(
      `  Mode: ${Config.isUsingDemoKey ? 'Demo (events queued locally)' : 'Live (sending to Segment)'}`,
    );

    return () => {
      client.flush();
    };
  }, []);

  const recordEvent = () => {
    setEventCount(prev => prev + 1);
    setLastEventTime(new Date().toLocaleTimeString());
  };

  const trackEvent = () => {
    recordEvent();
    clientRef.current?.track('Button Pressed', {
      button: 'Track Event',
      count: eventCount + 1,
      timestamp: new Date().toISOString(),
    });
  };

  const identifyUser = () => {
    recordEvent();
    const userId = `demo-user-${Math.random().toString(36).substring(2, 10)}`;
    clientRef.current?.identify(userId, {
      name: 'Demo User',
      email: 'demo@example.com',
      plan: 'free',
      event_count: eventCount + 1,
    });
  };

  const trackScreen = () => {
    recordEvent();
    clientRef.current?.screen('Demo Screen', {
      screen_name: 'App',
      view_count: eventCount + 1,
    });
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>Segment RN Demo</Text>
          <Text style={styles.subtitle}>
            Analytics React Native SDK v2.21+
          </Text>
        </View>

        <View style={styles.counter}>
          <Text style={styles.counterNumber}>{eventCount}</Text>
          <Text style={styles.counterLabel}>Events Tracked</Text>
          {lastEventTime && (
            <Text style={styles.counterTime}>Last: {lastEventTime}</Text>
          )}
        </View>

        <View style={styles.buttons}>
          <TouchableOpacity
            style={[styles.button, styles.buttonTrack]}
            onPress={trackEvent}>
            <Text style={styles.buttonText}>Track Event</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.buttonIdentify]}
            onPress={identifyUser}>
            <Text style={styles.buttonText}>Identify User</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.buttonScreen]}
            onPress={trackScreen}>
            <Text style={styles.buttonText}>Track Screen</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  content: {
    flexGrow: 1,
    justifyContent: 'center',
    padding: 24,
  },
  header: {
    alignItems: 'center',
    marginBottom: 48,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  subtitle: {
    fontSize: 14,
    color: '#666666',
    marginTop: 4,
  },
  counter: {
    alignItems: 'center',
    backgroundColor: '#e8f0fe',
    borderRadius: 12,
    padding: 24,
    marginBottom: 48,
  },
  counterNumber: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#1a73e8',
  },
  counterLabel: {
    fontSize: 14,
    color: '#666666',
  },
  counterTime: {
    fontSize: 12,
    color: '#999999',
    marginTop: 4,
  },
  buttons: {
    gap: 16,
  },
  button: {
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonTrack: {
    backgroundColor: '#1a73e8',
  },
  buttonIdentify: {
    backgroundColor: '#34a853',
  },
  buttonScreen: {
    backgroundColor: '#9334e6',
  },
  buttonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});
