import { Redirect, useLocalSearchParams, useRouter } from 'expo-router';
import { useState } from 'react';
import { Platform, ScrollView } from 'react-native';
import {
  CustomSetPickerOverlay,
  LibraryWordDetailView,
  Word7000RouteScreen,
} from '../../../App';
import { useAppRouteBridge } from '../../lib/appRouteBridge';

export default function LibraryWordRoute() {
  const router = useRouter();
  const { source, wordId } = useLocalSearchParams<{ source?: string; wordId: string }>();
  const bridge = useAppRouteBridge();
  const [pickerOpen, setPickerOpen] = useState(false);
  const [newSetName, setNewSetName] = useState('');

  if (!bridge) {
    return <Redirect href="/" />;
  }

  const word = bridge.vocabularyWords.find((candidate) => candidate.id === wordId);
  if (!word) {
    return <Redirect href="/" />;
  }

  const closeRoute = () => {
    if (source !== 'home') {
      bridge.actions.restoreLibraryScroll();
    }
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
        <LibraryWordDetailView
          backDestination={source === 'home' ? 'home' : 'library'}
          progress={bridge.progress}
          studyMode={bridge.studyMode}
          word={word}
          onAddToSet={() => {
            setNewSetName('');
            setPickerOpen(true);
          }}
          onBack={closeRoute}
          onFavorite={() => bridge.actions.favoriteWord(word.id)}
        />
      </ScrollView>
      {pickerOpen && (
        <CustomSetPickerOverlay
          customSets={bridge.customSets}
          newSetName={newSetName}
          studyMode={bridge.studyMode}
          word={word}
          onAddToSet={(setId) => {
            bridge.actions.addWordToSet(word, setId);
            setPickerOpen(false);
          }}
          onClose={() => setPickerOpen(false)}
          onCreateAndAdd={() => {
            bridge.actions.createSetAndAddWord(word, newSetName);
            setPickerOpen(false);
          }}
          onNewSetNameChange={setNewSetName}
        />
      )}
    </Word7000RouteScreen>
  );
}
