import { Redirect, useRouter } from 'expo-router';
import { Platform, ScrollView } from 'react-native';
import { Word7000RouteScreen } from '../../App';
import { PersonalAnalyticsView } from '../components/PersonalAnalyticsView';
import { useAppRouteBridge } from '../lib/appRouteBridge';
import { localDateKey } from '../lib/streakReminder';

export default function PersonalStatsRoute() {
  const router = useRouter();
  const bridge = useAppRouteBridge();
  if (!bridge) {
    return <Redirect href="/" />;
  }

  const closeRoute = () => {
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace('/profile');
    }
  };

  return (
    <Word7000RouteScreen
      studyMode={bridge.studyMode}
      themeMode={bridge.themeMode}
      vocabularyWords={bridge.vocabularyWords}
    >
      <ScrollView
        alwaysBounceVertical={false}
        automaticallyAdjustContentInsets={false}
        contentContainerStyle={{ padding: 18, paddingBottom: 42 }}
        contentInsetAdjustmentBehavior="never"
        keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
        showsVerticalScrollIndicator={false}
        style={{ flex: 1 }}
      >
        <PersonalAnalyticsView
          onBack={closeRoute}
          progress={bridge.progress}
          studyMode={bridge.studyMode}
          themeMode={bridge.themeMode}
          today={localDateKey()}
          vocabularyWords={bridge.vocabularyWords}
        />
      </ScrollView>
    </Word7000RouteScreen>
  );
}
