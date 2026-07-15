import { Redirect, useRouter } from 'expo-router';
import { Platform, ScrollView } from 'react-native';
import { ProfileSettingsView, Word7000RouteScreen } from '../../App';
import { useAppRouteBridge } from '../lib/appRouteBridge';

export default function SettingsRoute() {
  const router = useRouter();
  const bridge = useAppRouteBridge();
  if (!bridge) {
    return <Redirect href="/" />;
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
        <ProfileSettingsView
          accountBusy={bridge.accountBusy}
          developerMessage={bridge.developerMessage}
          developerVocabulary={bridge.developerVocabulary}
          signedIn={bridge.signedIn}
          studyMode={bridge.studyMode}
          themeMode={bridge.themeMode}
          vocabularyCount={bridge.vocabularyWords.length}
          onBack={closeRoute}
          onClearDeveloperVocabulary={bridge.actions.clearDeveloperVocabulary}
          onConfirmDeleteAccountData={bridge.actions.confirmDeleteAccountData}
          onExportVocabulary={bridge.actions.exportVocabulary}
          onImportVocabulary={bridge.actions.importVocabulary}
          onOpenAppInfoLink={bridge.actions.openAppInfoLink}
          onThemeModeChange={bridge.actions.setThemeMode}
        />
      </ScrollView>
    </Word7000RouteScreen>
  );
}
