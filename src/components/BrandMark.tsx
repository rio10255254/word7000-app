import { StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

type BrandMarkProps = {
  size: number;
  style?: StyleProp<ViewStyle>;
};

export function BrandMark({ size, style }: BrandMarkProps) {
  const bookWidth = Math.round(size * 0.54);
  const bookHeight = Math.round(size * 0.58);
  const lineHeight = Math.max(2, Math.round(size * 0.032));

  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[
        styles.mark,
        {
          borderRadius: Math.round(size * 0.235),
          height: size,
          width: size,
        },
        style,
      ]}
    >
      <View
        style={[
          styles.book,
          {
            borderRadius: Math.round(size * 0.055),
            height: bookHeight,
            width: bookWidth,
          },
        ]}
      >
        <View
          style={[
            styles.spine,
            {
              left: Math.round(bookWidth * 0.18),
              width: Math.max(2, Math.round(bookWidth * 0.065)),
            },
          ]}
        />
        <View
          style={[
            styles.coverLine,
            {
              height: lineHeight,
              left: Math.round(bookWidth * 0.36),
              top: Math.round(bookHeight * 0.29),
              width: Math.round(bookWidth * 0.36),
            },
          ]}
        />
        <View
          style={[
            styles.coverLine,
            {
              height: lineHeight,
              left: Math.round(bookWidth * 0.36),
              top: Math.round(bookHeight * 0.45),
              width: Math.round(bookWidth * 0.27),
            },
          ]}
        />
        <View
          style={[
            styles.coverLine,
            {
              height: lineHeight,
              left: Math.round(bookWidth * 0.36),
              top: Math.round(bookHeight * 0.61),
              width: Math.round(bookWidth * 0.33),
            },
          ]}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  book: {
    backgroundColor: '#FFFFFF',
    overflow: 'hidden',
  },
  coverLine: {
    backgroundColor: '#2563EB',
    borderRadius: 99,
    position: 'absolute',
  },
  mark: {
    alignItems: 'center',
    backgroundColor: '#2563EB',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  spine: {
    backgroundColor: '#2563EB',
    bottom: 0,
    position: 'absolute',
    top: 0,
  },
});
