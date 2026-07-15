import { Redirect, useRouter } from 'expo-router';
import { Platform, ScrollView } from 'react-native';
import { ProfileCustomSetsView, Word7000RouteScreen } from '../../App';
import { useAppRouteBridge } from '../lib/appRouteBridge';

export default function CustomSetsRoute() {
  const router = useRouter();
  const bridge = useAppRouteBridge();
  if (!bridge) {
    return <Redirect href="/" />;
  }

  const closeRoute = () => {
    bridge.actions.restoreLibraryScroll();
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
        <ProfileCustomSetsView
          backLabel={bridge.studyMode === 'chinese' ? 'Back to library' : '返回字庫'}
          customSetMessage={bridge.customSetMessage}
          customSetSort={bridge.customSetSort}
          customSets={bridge.customSets}
          customSetState={bridge.customSetState}
          manualCustomWord={bridge.manualCustomWord}
          newSetName={bridge.newSetName}
          selectedCustomSetId={bridge.selectedCustomSetId}
          studyMode={bridge.studyMode}
          vocabularyWords={bridge.vocabularyWords}
          onAddManualCustomWord={bridge.actions.addManualCustomWord}
          onBack={closeRoute}
          onCreateCustomSet={bridge.actions.createCustomSet}
          onCustomSetSelect={bridge.actions.selectCustomSet}
          onCustomSetSortChange={bridge.actions.setCustomSetSort}
          onDeleteCustomSet={bridge.actions.deleteCustomSet}
          onImportCustomWords={bridge.actions.importCustomWords}
          onManualCustomWordChange={bridge.actions.manualCustomWordChange}
          onNewSetNameChange={bridge.actions.newSetNameChange}
          onRemoveWordFromSet={bridge.actions.removeWordFromSet}
          onRenameCustomSet={bridge.actions.renameCustomSet}
          onStartQuizSet={(setId) => {
            bridge.actions.startQuizSet(setId);
            closeRoute();
          }}
          onStartStudySet={(setId) => {
            bridge.actions.startStudySet(setId);
            closeRoute();
          }}
        />
      </ScrollView>
    </Word7000RouteScreen>
  );
}
