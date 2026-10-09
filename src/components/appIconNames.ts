import type { SFSymbol } from 'sf-symbols-typescript';

/**
 * One name per meaning across the app. iOS draws the SF Symbol; other
 * platforms draw the matching line icon.
 */
export const appIconSymbols = {
  bank: 'square.stack.3d.up.fill',
  book: 'book.fill',
  camera: 'camera.fill',
  chart: 'chart.bar.fill',
  check: 'checkmark',
  chevronDown: 'chevron.down',
  chevronRight: 'chevron.right',
  cloud: 'icloud.fill',
  eye: 'eye.fill',
  filter: 'line.3.horizontal.decrease',
  flame: 'flame.fill',
  gear: 'gearshape.fill',
  language: 'character.bubble.fill',
  library: 'books.vertical.fill',
  lock: 'lock.fill',
  paste: 'doc.on.clipboard',
  photos: 'photo.on.rectangle',
  plus: 'plus',
  review: 'arrow.counterclockwise',
  scan: 'doc.text.viewfinder',
  search: 'magnifyingglass',
  sparkles: 'sparkles',
  target: 'target',
  trash: 'trash',
  undo: 'arrow.uturn.backward',
  xmark: 'xmark',
} as const satisfies Record<string, SFSymbol>;

export type AppIconName = keyof typeof appIconSymbols;
