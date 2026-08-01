import { Platform } from 'react-native';
import { Stack, usePathname } from 'expo-router';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { AppBootstrap, AppDataProvider, tabLabelForMode, useAppStudyMode } from '../../../App';

function useActiveTab() {
  const pathname = usePathname();
  if (pathname.startsWith('/study')) {
    return 'study' as const;
  }
  if (pathname.startsWith('/quiz')) {
    return 'quiz' as const;
  }
  if (pathname.startsWith('/library')) {
    return 'library' as const;
  }
  if (pathname.startsWith('/profile')) {
    return 'profile' as const;
  }
  return 'home' as const;
}

// SF Symbols rather than drawn icons: the system tab bar renders them itself,
// which is what lets it apply Liquid Glass, the user's glass intensity setting
// and the scroll-down minimise behaviour without the app configuring any of it.
function Tabs() {
  const studyMode = useAppStudyMode();
  const activeTab = useActiveTab();

  return (
    <>
      {/* The real navigation bar, driven by the parent Stack: large title that
          shrinks as you scroll and a background that turns to glass at the
          same moment. It also completes the chain the tab bar needs — the
          system links its minimise behaviour to a native bar reacting to the
          same scroll view, which a hand-drawn header could never provide. */}
      <Stack.Screen
        options={{
          headerLargeTitle: true,
          // Web's fallback for native tabs is a pill pinned to the top, so a
          // header there would sit on top of it. That pill already says which
          // screen you are on, so web goes without one.
          headerShown: Platform.OS !== 'web',
          headerTransparent: true,
          title: tabLabelForMode(activeTab, studyMode),
        }}
      />
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
    </>
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
