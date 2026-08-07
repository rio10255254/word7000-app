import { Platform } from 'react-native';
import { Stack, usePathname } from 'expo-router';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { AppBootstrap, AppDataProvider, tabLabelForMode, useAppStudyMode } from '../../../App';
import { triggerPressHaptic } from '../../lib/haptics';

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
      {/* Keep the native header in normal document flow. A transparent large
          title is absolutely positioned by iOS and can overlap a tab's first
          frame while its scroll inset is settling. The compact bar gives all
          five tabs one stable top edge. */}
      <Stack.Screen
        options={{
          headerLargeTitle: false,
          // Web's fallback for native tabs is a pill pinned to the top, so a
          // header there would sit on top of it. That pill already says which
          // screen you are on, so web goes without one.
          headerShown: Platform.OS !== 'web',
          headerShadowVisible: false,
          headerTitleStyle: { fontSize: 21, fontWeight: '700' },
          headerTransparent: false,
          title: tabLabelForMode(activeTab, studyMode),
        }}
      />
      <NativeTabs
        minimizeBehavior="onScrollDown"
        screenListeners={{ tabPress: () => triggerPressHaptic('tab') }}
      >
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
