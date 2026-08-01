import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { AppBootstrap, AppDataProvider, tabLabelForMode, useAppStudyMode } from '../../../App';

// SF Symbols rather than drawn icons: the system tab bar renders them itself,
// which is what lets it apply Liquid Glass, the user's glass intensity setting
// and the scroll-down minimise behaviour without the app configuring any of it.
function Tabs() {
  const studyMode = useAppStudyMode();

  return (
    <NativeTabs minimizeBehavior="onScrollDown">
      <NativeTabs.Trigger name="index">
        <NativeTabs.Trigger.Icon sf={{ default: 'house', selected: 'house.fill' }} />
        <NativeTabs.Trigger.Label>{tabLabelForMode('home', studyMode)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="study">
        <NativeTabs.Trigger.Icon sf={{ default: 'book', selected: 'book.fill' }} />
        <NativeTabs.Trigger.Label>{tabLabelForMode('study', studyMode)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="quiz">
        <NativeTabs.Trigger.Icon sf={{ default: 'target', selected: 'target' }} />
        <NativeTabs.Trigger.Label>{tabLabelForMode('quiz', studyMode)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="library">
        <NativeTabs.Trigger.Icon sf={{ default: 'books.vertical', selected: 'books.vertical.fill' }} />
        <NativeTabs.Trigger.Label>{tabLabelForMode('library', studyMode)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="profile">
        <NativeTabs.Trigger.Icon sf={{ default: 'person', selected: 'person.fill' }} />
        <NativeTabs.Trigger.Label>{tabLabelForMode('profile', studyMode)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}

export default function TabsLayout() {
  return (
    <AppBootstrap>
      <AppDataProvider>
        <Tabs />
      </AppDataProvider>
    </AppBootstrap>
  );
}
