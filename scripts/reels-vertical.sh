#!/usr/bin/env bash
# 把橫式影片（例如 16:10 的螢幕錄影）轉成 9:16 直式影片，給 Reels / Shorts / TikTok 用。
# 不裁切：前景保留完整畫面，上下空白用「同一支影片放大＋模糊」填滿（也可以改成純色）。
set -eo pipefail

usage() {
  cat <<'EOF'
用法：scripts/reels-vertical.sh [選項] 影片.mp4 [更多影片 ...]

每支影片會在旁邊產生 <檔名>_reels.mp4（1080x1920、H.264 + AAC，可直接上傳）。

選項：
  -b, --bg blur|black|white|#RRGGBB
                    背景：模糊的原影片（預設）或純色
  -z, --zoom 1.0    前景放大倍率。1.0 = 完整畫面、完全不裁；
                    1.2 = 放大 20%，左右各切掉一點點，畫面比較大
  -y, --offset 0    前景上下位移（像素，負數往上）。
                    Reels 底部有文字說明會蓋住，可以試 -150
  -o, --out 檔名    指定輸出檔（只處理一支影片時）
  -q, --crf 18      畫質，數字越小越清楚、檔案越大（建議 16–23）
  -h, --help        顯示說明

範例：
  scripts/reels-vertical.sh demo.mp4
  scripts/reels-vertical.sh -z 1.25 -y -120 demo.mp4
  scripts/reels-vertical.sh -b black ~/Desktop/*.mov
EOF
}

W=1080
H=1920
bg=blur
zoom=1.0
offset=0
crf=18
out=""
inputs=()

while [ $# -gt 0 ]; do
  case "$1" in
    -b|--bg) bg="$2"; shift 2 ;;
    -z|--zoom) zoom="$2"; shift 2 ;;
    -y|--offset) offset="$2"; shift 2 ;;
    -o|--out) out="$2"; shift 2 ;;
    -q|--crf) crf="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do inputs+=("$1"); shift; done ;;
    -*) echo "不認得的選項：$1" >&2; usage >&2; exit 1 ;;
    *) inputs+=("$1"); shift ;;
  esac
done

if [ ${#inputs[@]} -eq 0 ]; then usage >&2; exit 1; fi
if [ -n "$out" ] && [ ${#inputs[@]} -gt 1 ]; then
  echo "-o 只能搭配一支影片使用" >&2; exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "找不到 ffmpeg。Mac 請先執行：brew install ffmpeg" >&2; exit 1
fi
if ! awk -v z="$zoom" 'BEGIN { exit !(z + 0 >= 1 && z + 0 <= 3) }'; then
  echo "--zoom 要介於 1 到 3 之間" >&2; exit 1
fi
case "$offset" in ''|*[!0-9-]*) echo "--offset 要是整數" >&2; exit 1 ;; esac
case "$crf" in ''|*[!0-9]*) echo "--crf 要是整數" >&2; exit 1 ;; esac

# 前景寬度（偶數）。zoom > 1 時會比 1080 寬，再從中間切回 1080。
fgw=$(awk -v w="$W" -v z="$zoom" 'BEGIN { printf "%d", int(w * z / 2 + 0.5) * 2 }')
fg="scale=${fgw}:-2:flags=lanczos,crop=w='min(iw,${W})':h='min(ih,${H})',setsar=1"

if [ "$bg" = "blur" ]; then
  # 背景先縮小再模糊再放大：速度快、模糊也比較柔。
  bw=$((W / 4)); bh=$((H / 4))
  filter="[0:v]split=2[bgsrc][fgsrc];\
[bgsrc]scale=${bw}:${bh}:force_original_aspect_ratio=increase,crop=${bw}:${bh},\
gblur=sigma=8,eq=brightness=-0.08:saturation=1.15,scale=${W}:${H},setsar=1[bg];\
[fgsrc]${fg}[fg];\
[bg][fg]overlay=x=(W-w)/2:y=(H-h)/2+(${offset}),format=yuv420p[v]"
else
  filter="[0:v]${fg},\
pad=${W}:${H}:x=(ow-iw)/2:y='max(0,min(oh-ih,(oh-ih)/2+(${offset})))':color=${bg},\
format=yuv420p[v]"
fi

for in in "${inputs[@]}"; do
  if [ ! -f "$in" ]; then echo "找不到檔案：$in" >&2; exit 1; fi
  dest="${out:-${in%.*}_reels.mp4}"
  echo "▶ $in → $dest"
  ffmpeg -hide_banner -loglevel error -stats -y -i "$in" \
    -filter_complex "$filter" -map '[v]' -map '0:a?' \
    -c:v libx264 -preset medium -crf "$crf" -profile:v high -pix_fmt yuv420p \
    -fps_mode cfr -fpsmax 60 \
    -c:a aac -b:a 192k -ar 48000 \
    -movflags +faststart "$dest"
done
echo "✓ 完成"
