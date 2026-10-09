import * as Updates from 'expo-updates';
import { Component, type ErrorInfo, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { BrandMark } from './BrandMark';

type Props = { children: ReactNode };
type State = { failed: boolean };

export class AppErrorBoundary extends Component<Props, State> {
  state: State = { failed: false };

  static getDerivedStateFromError(): State {
    return { failed: true };
  }

  componentDidCatch(_error: Error, _info: ErrorInfo): void {
    // Keep the installed app recoverable even when a render failure escapes a screen.
  }

  private reopen = () => {
    if (Updates.isEnabled) {
      void Updates.reloadAsync().catch(() => this.setState({ failed: false }));
      return;
    }
    this.setState({ failed: false });
  };

  render() {
    if (!this.state.failed) {
      return this.props.children;
    }

    return (
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.card}>
          <BrandMark size={64} style={styles.mark} />
          <Text style={styles.title}>Word7000 暫時無法顯示</Text>
          <Text style={styles.body}>你的學習紀錄仍保存在裝置中。重新開啟即可繼續。</Text>
          <Text style={styles.english}>Your progress is safe. Reopen the app to continue.</Text>
          <Pressable accessibilityRole="button" onPress={this.reopen} style={styles.button}>
            <Text style={styles.buttonText}>重新開啟</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }
}

const styles = StyleSheet.create({
  body: { color: '#4B5563', fontSize: 15, lineHeight: 22, textAlign: 'center' },
  button: {
    alignItems: 'center',
    alignSelf: 'stretch',
    backgroundColor: '#007AFF',
    borderRadius: 10,
    justifyContent: 'center',
    marginTop: 8,
    minHeight: 48,
  },
  buttonText: { color: '#FFFFFF', fontSize: 16, fontWeight: '700' },
  card: { alignItems: 'center', gap: 10, maxWidth: 360, paddingHorizontal: 28 },
  english: { color: '#6B7280', fontSize: 13, lineHeight: 19, textAlign: 'center' },
  mark: {
    borderRadius: 16,
  },
  safeArea: { alignItems: 'center', backgroundColor: '#F2F2F7', flex: 1, justifyContent: 'center' },
  title: { color: '#111827', fontSize: 21, fontWeight: '800', textAlign: 'center' },
});
