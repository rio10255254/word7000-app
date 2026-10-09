import { Redirect, useRouter } from 'expo-router';
import { lazy, Suspense, useEffect } from 'react';
import { ActivityIndicator, Platform, ScrollView } from 'react-native';
import { Word7000RouteScreen } from '../../App';
import { useAppRouteBridge } from '../lib/appRouteBridge';

// Split out of the main bundle: only signed-in learners ever open it.
const ScanWordsView = lazy(() =>
  import('../components/ScanWordsView').then((module) => ({ default: module.ScanWordsView })),
);

export default function ScanWordsRoute() {
  const router = useRouter();
  const bridge = useAppRouteBridge();
  useEffect(() => {
    if (bridge && !bridge.signedIn) {
      bridge.actions.requestAccountUpgrade('customSets');
    }
  }, [bridge?.signedIn]);
  if (!bridge) {
    return <Redirect href="/" />;
  }
  // Scanned banks sync with the account, the same rule as custom sets.
  if (!bridge.signedIn) {
    return <Redirect href="/library" />;
  }

  const closeRoute = () => {
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace('/');
    }
  };

  return (
    <Word7000RouteScreen
      studyMode={bridge.studyMode}
      themeMode={bridge.themeMode}
      vocabularyWords={bridge.vocabularyWords}
    >
      <ScrollView
        automaticallyAdjustKeyboardInsets={Platform.OS === 'ios'}
        contentContainerStyle={{ padding: 18, paddingBottom: 42 }}
        keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        style={{ flex: 1 }}
      >
        <Suspense fallback={<ActivityIndicator style={{ marginTop: 40 }} />}>
          <ScanWordsView
            sets={bridge.customSets}
            studyMode={bridge.studyMode}
            themeMode={bridge.themeMode}
            onBack={closeRoute}
            onSave={bridge.actions.saveScannedWords}
            onStudy={() => router.replace('/study')}
          />
        </Suspense>
      </ScrollView>
    </Word7000RouteScreen>
  );
}
