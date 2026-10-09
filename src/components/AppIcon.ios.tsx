import { requireOptionalNativeModule } from 'expo';
import { SymbolView } from 'expo-symbols';
import { AppLineIcon, type AppIconProps } from './AppLineIcon';
import { appIconSymbols } from './appIconNames';

// Builds made before expo-symbols was added have no native symbol view. They
// get the line icons instead of a crash.
const symbolsAvailable = Boolean(requireOptionalNativeModule('SymbolModule'));

export function AppIcon(props: AppIconProps) {
  if (!symbolsAvailable) {
    return <AppLineIcon {...props} />;
  }
  const { color, name, size = 20, weight = 'semibold' } = props;
  return (
    <SymbolView
      name={appIconSymbols[name]}
      resizeMode="scaleAspectFit"
      size={size}
      tintColor={color}
      weight={weight}
    />
  );
}
