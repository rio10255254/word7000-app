import {
  BookOpen,
  Camera,
  ChartColumn,
  Check,
  ChevronDown,
  ChevronRight,
  ClipboardPaste,
  Cloud,
  Eye,
  Flame,
  Images,
  Languages,
  Layers,
  Library,
  Lock,
  Plus,
  RotateCcw,
  ScanText,
  Search,
  Settings,
  SlidersHorizontal,
  Sparkles,
  Target,
  Trash2,
  Undo2,
  X,
} from 'lucide-react-native';
import type { ColorValue } from 'react-native';
import type { AppIconName } from './appIconNames';

export type AppIconProps = {
  color: ColorValue;
  name: AppIconName;
  size?: number;
  weight?: 'medium' | 'regular' | 'semibold' | 'bold';
};

const lucideIcons = {
  bank: Layers,
  book: BookOpen,
  camera: Camera,
  chart: ChartColumn,
  check: Check,
  chevronDown: ChevronDown,
  chevronRight: ChevronRight,
  cloud: Cloud,
  eye: Eye,
  filter: SlidersHorizontal,
  flame: Flame,
  gear: Settings,
  language: Languages,
  library: Library,
  lock: Lock,
  paste: ClipboardPaste,
  photos: Images,
  plus: Plus,
  review: RotateCcw,
  scan: ScanText,
  search: Search,
  sparkles: Sparkles,
  target: Target,
  trash: Trash2,
  undo: Undo2,
  xmark: X,
} as const satisfies Record<AppIconName, unknown>;

const strokeForWeight = { bold: 2.8, medium: 2.2, regular: 2, semibold: 2.5 } as const;

export function AppLineIcon({ color, name, size = 20, weight = 'semibold' }: AppIconProps) {
  const Icon = lucideIcons[name];
  return <Icon color={color as string} size={size} strokeWidth={strokeForWeight[weight]} />;
}
