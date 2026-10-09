import type { ImagePickerOptions } from 'expo-image-picker';
import { Camera, Check, ChevronLeft, ClipboardPaste, Images, Plus, ScanText, Trash2 } from 'lucide-react-native';
import { useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';
import { iosVisual } from '../design/iosVisualSystem';
import type { CustomVocabSet } from '../lib/customSets';
import { triggerPressHaptic } from '../lib/haptics';
import { linesFromPlainText, parseScannedLines, type ScannedLine } from '../lib/scanParser';
import { defaultScanBankName, isScannedWordId, type ReviewedScanWord } from '../lib/wordBanks';
import { isWordScannerAvailable, recognizeTextInImage } from '../../modules/word-scanner';

type StudyMode = 'chinese' | 'english';
type Stage = 'start' | 'reading' | 'review' | 'saved';
type ReviewRow = ReviewedScanWord & { include: boolean; key: string };
type SaveTarget = { kind: 'existing'; setId: string } | { kind: 'new'; name: string };

const copy = {
  english: {
    back: '返回',
    title: '掃描單字表',
    intro: '拍下或選一張單字表照片，App 會在手機上讀出英文單字和紙上印的中文意思。照片不會上傳。',
    tips: ['光線充足、紙張拍正', '一次拍一頁，字不要太小', '英文和中文意思要在同一行、同一列，或意思在單字正下方'],
    takePhoto: '拍照',
    choosePhoto: '從相簿選擇',
    pasteTitle: '或貼上文字',
    pasteHint: '在「照片」App 長按文字即可拷貝（原況文字），再貼到這裡',
    pastePlaceholder: 'abandon v. 放棄\nbenefit n. 好處',
    readPasted: '讀取貼上的文字',
    unavailable: '這個版本還不能直接辨識照片。請更新到最新的 iPhone App，或先用下方「貼上文字」。',
    reading: '正在手機上辨識…',
    readFailed: '辨識失敗，請換一張更清楚的照片再試一次。',
    cameraDenied: '沒有相機權限，請到「設定」允許 Word7000 使用相機，或改從相簿選擇。',
    found: (count: number) => `找到 ${count} 個單字`,
    reviewHint: '儲存前可以直接修改英文或中文；取消勾選的不會存入。',
    noneFound: '沒有找到成對的英文和中文意思。可以換一張更清楚的照片，或用「新增一列」手動加入。',
    word: '英文',
    meaning: '中文意思',
    pos: '詞性',
    addRow: '新增一列',
    removeRow: '刪除這一列',
    includeRow: (word: string) => `存入 ${word || '這一列'}`,
    saveTo: '存到',
    newBank: '新字庫',
    existingBank: '現有字庫',
    bankName: '字庫名稱',
    save: (count: number) => `存入字庫（${count} 個）`,
    rescan: '重新掃描',
    savedTitle: '已存入字庫',
    savedText: (count: number, name: string) => `${count} 個單字已加入「${name}」，學習、測驗和字庫都已切換到這個字庫。`,
    startStudy: '開始學習',
    scanAnother: '再掃一張',
  },
  chinese: {
    back: 'Back',
    title: 'Scan a Word Sheet',
    intro: 'Take or choose a photo of a vocabulary sheet. The app reads each English word and the Chinese meaning printed next to it, on your phone. The photo is not uploaded.',
    tips: ['Good light, paper flat and straight', 'One page per photo, text not too small', 'Meaning on the same line, in the same row, or right under the word'],
    takePhoto: 'Take Photo',
    choosePhoto: 'Choose Photo',
    pasteTitle: 'Or paste text',
    pasteHint: 'In Photos, touch and hold text to copy it (Live Text), then paste it here',
    pastePlaceholder: 'abandon v. 放棄\nbenefit n. 好處',
    readPasted: 'Read Pasted Text',
    unavailable: 'This version cannot read photos yet. Update to the latest iPhone app, or use "Paste text" below.',
    reading: 'Reading on your phone...',
    readFailed: 'Could not read that photo. Try a clearer one.',
    cameraDenied: 'Camera access is off. Allow it for Word7000 in Settings, or choose a photo instead.',
    found: (count: number) => `${count} words found`,
    reviewHint: 'Fix any word or meaning before saving. Unchecked rows are skipped.',
    noneFound: 'No word and meaning pairs were found. Try a clearer photo, or add rows by hand.',
    word: 'English',
    meaning: 'Chinese meaning',
    pos: 'Part',
    addRow: 'Add Row',
    removeRow: 'Delete this row',
    includeRow: (word: string) => `Save ${word || 'this row'}`,
    saveTo: 'Save to',
    newBank: 'New bank',
    existingBank: 'Existing bank',
    bankName: 'Bank name',
    save: (count: number) => `Save ${count} Words`,
    rescan: 'Scan Again',
    savedTitle: 'Saved',
    savedText: (count: number, name: string) => `${count} words were added to "${name}". Study, quiz and library now use this bank.`,
    startStudy: 'Start Studying',
    scanAnother: 'Scan Another',
  },
} as const;

export function ScanWordsView({
  sets,
  studyMode,
  themeMode,
  onBack,
  onSave,
  onStudy,
}: {
  sets: CustomVocabSet[];
  studyMode: StudyMode;
  themeMode: 'dark' | 'light';
  onBack: () => void;
  onSave: (rows: ReviewedScanWord[], target: SaveTarget) => string | null;
  onStudy: () => void;
}) {
  const ui = copy[studyMode];
  const palette = themeMode === 'dark' ? iosVisual.dark : iosVisual.light;
  const themed = useMemo(() => buildThemedStyles(palette), [palette]);
  const scannerAvailable = isWordScannerAvailable();
  const scanBanks = useMemo(() => sets.filter((set) => set.wordIds.some(isScannedWordId)), [sets]);
  const [stage, setStage] = useState<Stage>('start');
  const [message, setMessage] = useState('');
  const [pasted, setPasted] = useState('');
  const [rows, setRows] = useState<ReviewRow[]>([]);
  const [targetKind, setTargetKind] = useState<'existing' | 'new'>('new');
  const [newBankName, setNewBankName] = useState(() => defaultScanBankName(new Date(), studyMode));
  const [existingSetId, setExistingSetId] = useState<string | null>(scanBanks[0]?.id ?? sets[0]?.id ?? null);
  const [saved, setSaved] = useState<{ count: number; name: string } | null>(null);
  const includedRows = rows.filter((row) => row.include && row.word.trim() && row.meaningZh.trim());

  function showLines(lines: ScannedLine[]) {
    const candidates = parseScannedLines(lines);
    setRows(candidates.map((candidate) => ({ ...candidate, include: true })));
    setStage('review');
  }

  async function readImage(source: 'camera' | 'library') {
    setMessage('');
    try {
      // Loaded on demand: the picker is only usable where the native scanner
      // exists, so the web bundle should not carry it up front.
      const ImagePicker = await import('expo-image-picker');
      if (source === 'camera') {
        const permission = await ImagePicker.requestCameraPermissionsAsync();
        if (!permission.granted) {
          setMessage(ui.cameraDenied);
          return;
        }
      }
      const options: ImagePickerOptions = { mediaTypes: ['images'], quality: 1 };
      const result = source === 'camera'
        ? await ImagePicker.launchCameraAsync(options)
        : await ImagePicker.launchImageLibraryAsync(options);
      const uri = result.canceled ? null : result.assets?.[0]?.uri;
      if (!uri) {
        return;
      }
      setStage('reading');
      showLines(await recognizeTextInImage(uri));
    } catch {
      setStage('start');
      setMessage(ui.readFailed);
    }
  }

  function readPasted() {
    if (!pasted.trim()) {
      return;
    }
    setMessage('');
    showLines(linesFromPlainText(pasted));
  }

  function updateRow(key: string, patch: Partial<ReviewRow>) {
    setRows((current) => current.map((row) => (row.key === key ? { ...row, ...patch } : row)));
  }

  function addRow() {
    setRows((current) => [...current, { include: true, key: `manual-${Date.now()}`, meaningZh: '', partOfSpeech: '', word: '' }]);
  }

  function save() {
    if (includedRows.length === 0) {
      return;
    }
    const target: SaveTarget = targetKind === 'existing' && existingSetId
      ? { kind: 'existing', setId: existingSetId }
      : { kind: 'new', name: newBankName };
    const savedId = onSave(
      includedRows.map(({ meaningZh, partOfSpeech, word }) => ({ meaningZh, partOfSpeech, word })),
      target,
    );
    if (!savedId) {
      return;
    }
    const name = target.kind === 'existing'
      ? sets.find((set) => set.id === target.setId)?.name ?? ''
      : newBankName.trim() || defaultScanBankName(new Date(), studyMode);
    setSaved({ count: includedRows.length, name });
    setStage('saved');
  }

  function restart() {
    setRows([]);
    setPasted('');
    setMessage('');
    setSaved(null);
    setStage('start');
  }

  return (
    <View style={styles.stack} testID="scan-words-screen">
      <ScanButton onPress={stage === 'review' ? restart : onBack} style={[styles.backButton, themed.surface]} tone="secondary">
        <ChevronLeft size={18} color={palette.label} strokeWidth={2.5} />
        <Text style={[styles.backText, themed.label]}>{stage === 'review' ? ui.rescan : ui.back}</Text>
      </ScanButton>

      {stage === 'start' && (
        <>
          <View style={[styles.card, themed.surface]}>
            <View style={[styles.heroIcon, themed.accentSoft]}>
              <ScanText size={30} color={palette.accent} strokeWidth={2.2} />
            </View>
            <Text style={[styles.title, themed.label]}>{ui.title}</Text>
            <Text style={[styles.body, themed.secondary]}>{ui.intro}</Text>
            <View style={styles.tips}>
              {ui.tips.map((tip) => (
                <View key={tip} style={styles.tipRow}>
                  <Check size={15} color={palette.green} strokeWidth={2.6} />
                  <Text style={[styles.tipText, themed.secondary]}>{tip}</Text>
                </View>
              ))}
            </View>
            {!scannerAvailable && <Text style={[styles.notice, themed.notice]}>{ui.unavailable}</Text>}
            {Boolean(message) && <Text style={[styles.notice, themed.notice]}>{message}</Text>}
            <View style={styles.row}>
              <ScanButton disabled={!scannerAvailable} onPress={() => void readImage('camera')} style={[styles.primary, { backgroundColor: palette.accent }]} testID="scan-take-photo" tone="primary">
                <Camera size={18} color="#FFFFFF" strokeWidth={2.3} />
                <Text style={styles.primaryText}>{ui.takePhoto}</Text>
              </ScanButton>
              <ScanButton disabled={!scannerAvailable} onPress={() => void readImage('library')} style={[styles.secondary, themed.secondaryButton]} testID="scan-choose-photo" tone="secondary">
                <Images size={18} color={palette.accent} strokeWidth={2.3} />
                <Text style={[styles.secondaryText, { color: palette.accent }]}>{ui.choosePhoto}</Text>
              </ScanButton>
            </View>
          </View>

          <View style={[styles.card, themed.surface]}>
            <Text style={[styles.sectionTitle, themed.label]}>{ui.pasteTitle}</Text>
            <Text style={[styles.caption, themed.secondary]}>{ui.pasteHint}</Text>
            <TextInput
              accessibilityLabel={ui.pasteTitle}
              autoCapitalize="none"
              autoCorrect={false}
              multiline
              onChangeText={setPasted}
              placeholder={ui.pastePlaceholder}
              placeholderTextColor={palette.labelTertiary}
              style={[styles.pasteInput, themed.input]}
              testID="scan-paste-input"
              textAlignVertical="top"
              value={pasted}
            />
            <ScanButton disabled={!pasted.trim()} onPress={readPasted} style={[styles.secondary, themed.secondaryButton]} testID="scan-read-pasted" tone="secondary">
              <ClipboardPaste size={18} color={palette.accent} strokeWidth={2.3} />
              <Text style={[styles.secondaryText, { color: palette.accent }]}>{ui.readPasted}</Text>
            </ScanButton>
          </View>
        </>
      )}

      {stage === 'reading' && (
        <View style={[styles.card, styles.center, themed.surface]}>
          <ActivityIndicator color={palette.accent} size="large" />
          <Text style={[styles.body, themed.secondary]}>{ui.reading}</Text>
        </View>
      )}

      {stage === 'review' && (
        <>
          <View style={[styles.card, themed.surface]} testID="scan-review">
            <Text style={[styles.title, themed.label]}>{ui.found(rows.length)}</Text>
            <Text style={[styles.caption, themed.secondary]}>{rows.length > 0 ? ui.reviewHint : ui.noneFound}</Text>
            {rows.map((row) => (
              <View key={row.key} style={[styles.reviewRow, themed.rowBorder, !row.include && styles.reviewRowOff]}>
                <ScanButton
                  accessibilityLabel={ui.includeRow(row.word)}
                  accessibilityRole="checkbox"
                  accessibilityState={{ checked: row.include }}
                  onPress={() => updateRow(row.key, { include: !row.include })}
                  style={[styles.checkbox, row.include ? { backgroundColor: palette.accent, borderColor: palette.accent } : themed.checkboxOff]}
                  tone="chip"
                >
                  {row.include ? <Check size={14} color="#FFFFFF" strokeWidth={3} /> : null}
                </ScanButton>
                <View style={styles.reviewFields}>
                  <View style={styles.row}>
                    <TextInput
                      accessibilityLabel={ui.word}
                      autoCapitalize="none"
                      autoCorrect={false}
                      onChangeText={(value) => updateRow(row.key, { word: value })}
                      placeholder={ui.word}
                      placeholderTextColor={palette.labelTertiary}
                      style={[styles.wordInput, themed.input]}
                      value={row.word}
                    />
                    <TextInput
                      accessibilityLabel={ui.pos}
                      autoCapitalize="none"
                      autoCorrect={false}
                      onChangeText={(value) => updateRow(row.key, { partOfSpeech: value })}
                      placeholder={ui.pos}
                      placeholderTextColor={palette.labelTertiary}
                      style={[styles.posInput, themed.input]}
                      value={row.partOfSpeech}
                    />
                  </View>
                  <TextInput
                    accessibilityLabel={ui.meaning}
                    onChangeText={(value) => updateRow(row.key, { meaningZh: value })}
                    placeholder={ui.meaning}
                    placeholderTextColor={palette.labelTertiary}
                    style={[styles.meaningInput, themed.input]}
                    value={row.meaningZh}
                  />
                </View>
                <ScanButton
                  accessibilityLabel={ui.removeRow}
                  onPress={() => setRows((current) => current.filter((item) => item.key !== row.key))}
                  style={styles.iconButton}
                  tone="icon"
                >
                  <Trash2 size={17} color={palette.red} strokeWidth={2.2} />
                </ScanButton>
              </View>
            ))}
            <ScanButton onPress={addRow} style={[styles.secondary, themed.secondaryButton]} testID="scan-add-row" tone="secondary">
              <Plus size={18} color={palette.accent} strokeWidth={2.4} />
              <Text style={[styles.secondaryText, { color: palette.accent }]}>{ui.addRow}</Text>
            </ScanButton>
          </View>

          <View style={[styles.card, themed.surface]}>
            <Text style={[styles.sectionTitle, themed.label]}>{ui.saveTo}</Text>
            <View style={[styles.segment, themed.segment]}>
              {(['new', 'existing'] as const).map((kind) => {
                const selected = targetKind === kind;
                const disabled = kind === 'existing' && sets.length === 0;
                return (
                  <ScanButton
                    accessibilityRole="radio"
                    accessibilityState={{ checked: selected, disabled }}
                    disabled={disabled}
                    key={kind}
                    onPress={() => setTargetKind(kind)}
                    style={[styles.segmentButton, selected && { backgroundColor: palette.accent }]}
                    tone="chip"
                  >
                    <Text style={[styles.segmentText, selected ? styles.segmentTextActive : themed.label]}>
                      {kind === 'new' ? ui.newBank : ui.existingBank}
                    </Text>
                  </ScanButton>
                );
              })}
            </View>
            {targetKind === 'new' ? (
              <TextInput
                accessibilityLabel={ui.bankName}
                onChangeText={setNewBankName}
                placeholder={ui.bankName}
                placeholderTextColor={palette.labelTertiary}
                style={[styles.meaningInput, themed.input]}
                testID="scan-bank-name"
                value={newBankName}
              />
            ) : (
              <View style={styles.chips}>
                {sets.map((set) => {
                  const selected = set.id === existingSetId;
                  return (
                    <ScanButton
                      accessibilityRole="radio"
                      accessibilityState={{ checked: selected }}
                      key={set.id}
                      onPress={() => setExistingSetId(set.id)}
                      style={[styles.chip, themed.secondaryButton, selected && { backgroundColor: palette.accent, borderColor: palette.accent }]}
                      tone="chip"
                    >
                      <Text numberOfLines={1} style={[styles.chipText, selected ? styles.segmentTextActive : themed.label]}>{set.name}</Text>
                    </ScanButton>
                  );
                })}
              </View>
            )}
            <ScanButton
              disabled={includedRows.length === 0}
              onPress={save}
              style={[styles.primary, { backgroundColor: palette.accent }]}
              testID="scan-save"
              tone="primary"
            >
              <Check size={18} color="#FFFFFF" strokeWidth={2.5} />
              <Text style={styles.primaryText}>{ui.save(includedRows.length)}</Text>
            </ScanButton>
          </View>
        </>
      )}

      {stage === 'saved' && saved && (
        <View style={[styles.card, styles.center, themed.surface]} testID="scan-saved">
          <View style={[styles.heroIcon, { backgroundColor: palette.greenSoft }]}>
            <Check size={30} color={palette.green} strokeWidth={2.6} />
          </View>
          <Text style={[styles.title, themed.label]}>{ui.savedTitle}</Text>
          <Text style={[styles.body, styles.centerText, themed.secondary]}>{ui.savedText(saved.count, saved.name)}</Text>
          <ScanButton onPress={onStudy} style={[styles.primary, styles.fullWidth, { backgroundColor: palette.accent }]} testID="scan-start-study" tone="primary">
            <Text style={styles.primaryText}>{ui.startStudy}</Text>
          </ScanButton>
          <ScanButton onPress={restart} style={[styles.secondary, styles.fullWidth, themed.secondaryButton]} tone="secondary">
            <ScanText size={18} color={palette.accent} strokeWidth={2.3} />
            <Text style={[styles.secondaryText, { color: palette.accent }]}>{ui.scanAnother}</Text>
          </ScanButton>
        </View>
      )}
    </View>
  );
}

function ScanButton({
  children,
  disabled,
  style,
  tone,
  ...props
}: Omit<PressableProps, 'style'> & {
  style?: StyleProp<ViewStyle>;
  tone: 'chip' | 'icon' | 'primary' | 'secondary';
}) {
  return (
    <Pressable
      {...props}
      accessibilityRole={props.accessibilityRole ?? 'button'}
      disabled={disabled}
      onPressIn={(event) => {
        if (!disabled) {
          triggerPressHaptic(tone);
        }
        props.onPressIn?.(event);
      }}
      style={({ pressed }) => [style, pressed && !disabled && styles.pressed, disabled && styles.disabled]}
    >
      {children}
    </Pressable>
  );
}

function buildThemedStyles(palette: (typeof iosVisual)['light'] | (typeof iosVisual)['dark']) {
  return StyleSheet.create({
    accentSoft: { backgroundColor: palette.accentSoft },
    checkboxOff: { borderColor: palette.separatorStrong },
    input: { backgroundColor: palette.surfaceSecondary, borderColor: palette.separator, color: palette.label },
    label: { color: palette.label },
    notice: { backgroundColor: palette.orangeSoft, color: palette.label },
    rowBorder: { borderBottomColor: palette.separator },
    secondary: { color: palette.labelSecondary },
    secondaryButton: { backgroundColor: palette.surface, borderColor: palette.accentBorder },
    segment: { backgroundColor: palette.surfaceTertiary },
    surface: { backgroundColor: palette.surface, borderColor: palette.separator },
  });
}

const styles = StyleSheet.create({
  backButton: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderRadius: 999,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  backText: { fontSize: 15, fontWeight: '600' },
  body: { fontSize: 15, lineHeight: 22 },
  caption: { fontSize: 13, lineHeight: 19 },
  card: {
    borderCurve: 'continuous',
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    gap: 12,
    padding: 18,
  },
  center: { alignItems: 'center' },
  centerText: { textAlign: 'center' },
  checkbox: {
    alignItems: 'center',
    borderRadius: 7,
    borderWidth: 1.5,
    height: 24,
    justifyContent: 'center',
    marginTop: 10,
    width: 24,
  },
  chip: {
    borderRadius: 999,
    borderWidth: 1,
    maxWidth: '100%',
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  chipText: { fontSize: 14, fontWeight: '600' },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  disabled: { opacity: 0.45 },
  fullWidth: { alignSelf: 'stretch', flex: 0 },
  heroIcon: {
    alignItems: 'center',
    alignSelf: 'center',
    borderRadius: 30,
    height: 60,
    justifyContent: 'center',
    width: 60,
  },
  iconButton: { alignItems: 'center', height: 40, justifyContent: 'center', marginTop: 2, width: 36 },
  meaningInput: {
    // Web TextInputs have an intrinsic width; stretch them to the row.
    alignSelf: 'stretch',
    borderRadius: 10,
    width: '100%',
    borderWidth: StyleSheet.hairlineWidth,
    fontSize: 16,
    minHeight: 42,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  notice: {
    borderRadius: 10,
    fontSize: 14,
    lineHeight: 20,
    overflow: 'hidden',
    padding: 10,
  },
  pasteInput: {
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    fontSize: 16,
    minHeight: 120,
    padding: 12,
  },
  posInput: {
    borderRadius: 10,
    flexShrink: 0,
    borderWidth: StyleSheet.hairlineWidth,
    fontSize: 15,
    minHeight: 42,
    paddingHorizontal: 10,
    width: 76,
  },
  pressed: { opacity: 0.75, transform: [{ scale: 0.985 }] },
  primary: {
    alignItems: 'center',
    borderRadius: 12,
    borderCurve: 'continuous',
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 50,
    paddingHorizontal: 14,
  },
  primaryText: { color: '#FFFFFF', fontSize: 16, fontWeight: '700' },
  reviewFields: { flex: 1, gap: 8, minWidth: 0 },
  reviewRow: {
    alignItems: 'flex-start',
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 10,
    paddingBottom: 12,
  },
  reviewRowOff: { opacity: 0.5 },
  row: { flexDirection: 'row', gap: 10 },
  secondary: {
    alignItems: 'center',
    borderRadius: 12,
    borderCurve: 'continuous',
    borderWidth: 1,
    flex: 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    minHeight: 50,
    paddingHorizontal: 14,
  },
  secondaryText: { fontSize: 16, fontWeight: '700' },
  sectionTitle: { fontSize: 17, fontWeight: '700' },
  segment: { borderRadius: 12, flexDirection: 'row', gap: 4, padding: 4 },
  segmentButton: { alignItems: 'center', borderRadius: 9, flex: 1, minHeight: 40, justifyContent: 'center' },
  segmentText: { fontSize: 15, fontWeight: '600' },
  segmentTextActive: { color: '#FFFFFF' },
  stack: { gap: 14 },
  tipRow: { alignItems: 'flex-start', flexDirection: 'row', gap: 8 },
  tipText: { flex: 1, fontSize: 14, lineHeight: 20 },
  tips: { gap: 6 },
  title: { fontSize: 22, fontWeight: '800' },
  wordInput: {
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    flex: 1,
    minWidth: 0,
    fontSize: 17,
    fontWeight: '700',
    minHeight: 42,
    paddingHorizontal: 12,
  },
});
