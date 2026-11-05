#!/usr/bin/env bash
# The remote control behind the broadcast workflows (see .github/workflows/remote-*.yml).
# ACTION: post | status | usage | fix | bank-publish | bank-remove | take-down | lift-update. Needs SUPABASE_ACCESS_TOKEN and PROJECT_REF.
set -euo pipefail
: "${TITLE_ZH:=}" "${BODY_ZH:=}" "${TITLE_EN:=}" "${BODY_EN:=}" "${AUDIENCE:=all}" "${BELOW:=}" "${DAYS:=7}"
: "${LINK:=}" "${LINK_ZH:=}" "${LINK_EN:=}" "${PUSH:=false}" "${REQUIRE:=}"
keys=$(supabase projects api-keys --project-ref "$PROJECT_REF" -o json --reveal 2>/dev/null \
  || supabase projects api-keys --project-ref "$PROJECT_REF" -o json)
service=$(echo "$keys" | jq -r '([.[] | select(.name == "service_role")] + [.[] | select(.type == "secret")])[0].api_key')
[ -n "$service" ] && [ "$service" != "null" ] || { echo "::error::Could not read the project's service key"; exit 1; }
echo "::add-mask::$service"
rest="https://$PROJECT_REF.supabase.co/rest/v1"
headers=(-H "apikey: $service" -H 'Content-Type: application/json' -H 'Prefer: return=representation')
case "$service" in eyJ*) headers+=(-H "Authorization: Bearer $service") ;; esac
call() { curl -sS -w '\n%{http_code}' "$@" "${headers[@]}"; }
body_of() { echo "$1" | sed '$d'; }
code_of() { echo "$1" | tail -1; }
# "2.0.3" or "2.0.2 (4)" -> version and build
parse() {
  [[ "$1" =~ ^([0-9]+(\.[0-9]+){0,2})(\ \(([0-9]+)\))?$ ]] \
    || { echo "::error::'$1' must look like 2.0.3 or 2.0.2 (4)"; exit 1; }
  VERSION="${BASH_REMATCH[1]}"; BUILD="${BASH_REMATCH[4]:-}"
}
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Everything worth reading also goes to the run's summary page.
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
say() { echo "$*"; echo "$*" >> "$summary"; }

case "$ACTION" in
status)
  reply=$(call -X POST "$rest/rpc/app_version_summary" -d '{}')
  [ "$(code_of "$reply")" = "200" ] || { echo "::error::$(body_of "$reply")"; exit 1; }
  say "## 📱 大家裝的版本"
  say ""
  say "| 版本 | 建置 | 帳號數 | 7 天內打開過 | 可收推播的手機 |"
  say "|---|---|---|---|---|"
  body_of "$reply" | jq -r '.[] | "| \(.app_version) | \(.app_build // "-") | \(.installs) | \(.seen_last_7_days) | \(.push_devices) |"' | while read -r line; do say "$line"; done
  say ""
  say "## 🔔 登記推播的手機"
  say ""
  say "權杖只列最後 6 碼；最後登記時間是手機上次打開 App、把權杖送上來的時間。"
  say ""
  say "| 權杖 | 版本 | 對象 | 語言 | 測試機 | 最後登記（UTC） |"
  say "|---|---|---|---|---|---|"
  reply=$(call "$rest/push_devices?select=token,app_version,app_build,audience,language,tester,updated_at&order=updated_at.desc&limit=50")
  [ "$(code_of "$reply")" = "200" ] || { echo "::error::$(body_of "$reply")"; exit 1; }
  body_of "$reply" | jq -r '.[] | "| …\(.token[-6:]) | \(.app_version // "舊版")\(if .app_build then " (\(.app_build))" else "" end) | \(.audience) | \(.language) | \(if .tester then "是" else "" end) | \(.updated_at[0:16]) |"' | while read -r line; do say "$line"; done
  say ""
  say "## 📣 目前在線上的公告"
  reply=$(call "$rest/announcements?select=created_at,audience,title_zh,below_version,below_build,ends_at,push,pushed_at&active=eq.true&or=(ends_at.is.null,ends_at.gt.$now)&order=created_at.desc")
  body_of "$reply" | jq -r 'if length == 0 then "- 沒有" else .[] | "- **\(.title_zh)**：對象 \(.audience)\(if .below_version then "，只給 \(.below_version)\(if .below_build then " (\(.below_build))" else "" end) 以前" else "" end)；\(if .ends_at then "到 \(.ends_at[0:16]) UTC" else "直到下架" end)\(if .push then "；推播 \(if .pushed_at then "已送出" else "未送出" end)" else "" end)" end' | while read -r line; do say "$line"; done
  say ""
  say "## 📚 官方字庫"
  reply=$(call "$rest/official_banks?select=id,mode,name_zh,premium,active,updated_at,words&order=mode,sort,id")
  body_of "$reply" | jq -r 'if length == 0 then "- 沒有" else .[] | "- \(if .active then "🟢" else "⚪️ 已下架" end) **\(.name_zh)**（代號 \(.id)，\(if .mode == "chinese" then "學中文" else "學英文" end)，\(.words | length) 字\(if .premium then "，Premium" else "" end)，更新於 \(.updated_at[0:16]) UTC）" end' | while read -r line; do say "$line"; done
  reply=$(call "$rest/content_corrections?select=mode&active=eq.true")
  say "- 目前生效的單字校正：$(body_of "$reply" | jq length) 個"
  say ""
  say "## ⛔ 強制更新"
  reply=$(call "$rest/update_requirements?select=created_at,min_version,min_build&active=eq.true&order=created_at.desc&limit=1")
  body_of "$reply" | jq -r 'if length == 0 then "- 沒有" else .[] | "- 低於 **\(.min_version)\(if .min_build then " (\(.min_build))" else "" end)** 的都要更新（從 \(.created_at[0:16]) UTC 起）" end' | while read -r line; do say "$line"; done
  ;;
fix|bank-publish|bank-remove)
  SERVICE_KEY="$service" REST="$rest" node scripts/word-content.mjs
  ;;
usage)
  days="${DAYS:-7}"
  [[ "$days" =~ ^[0-9]+$ ]] || { echo "::error::days must be a whole number"; exit 1; }
  reply=$(call -X POST "$rest/rpc/usage_report" -d "{\"p_days\":$days}")
  [ "$(code_of "$reply")" = "200" ] || { echo "::error::$(body_of "$reply")"; exit 1; }
  body_of "$reply" | node scripts/usage-report.mjs
  ;;
take-down)
  reply=$(call -X PATCH "$rest/announcements?active=eq.true" -d '{"active":false}')
  [ "$(code_of "$reply")" = "200" ] || { echo "::error::$(body_of "$reply")"; exit 1; }
  say "🧹 已下架 $(body_of "$reply" | jq length) 則公告。已經看過的人不受影響，之後不會再有人看到。"
  ;;
lift-update)
  reply=$(call -X PATCH "$rest/update_requirements?active=eq.true" -d '{"active":false}')
  [ "$(code_of "$reply")" = "200" ] || { echo "::error::$(body_of "$reply")"; exit 1; }
  say "✅ 已解除 $(body_of "$reply" | jq length) 個強制更新。被擋住的人下次打開 App 就能用了。"
  ;;
post)
  [ -n "$TITLE_ZH" ] && [ -n "$BODY_ZH" ] || { echo "::error::A post needs title_zh and body_zh"; exit 1; }
  [[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "::error::days must be a whole number"; exit 1; }
  if [ -n "$LINK" ] && [ "$LINK" != "plus" ] && [ "$LINK" != "update" ] && [[ "$LINK" != https://* ]]; then
    echo "::error::link must start with https://, or be plus or update"; exit 1
  fi
  if [ -z "$TITLE_EN" ] || [ -z "$BODY_EN" ]; then
    echo "::warning::沒有填英文標題或內容：英文介面的使用者會看到中文。"
  fi
  below_version=""; below_build=""
  if [ -n "$BELOW" ]; then parse "$BELOW"; below_version="$VERSION"; below_build="$BUILD"; fi
  if [ -n "$REQUIRE" ]; then parse "$REQUIRE"; fi
  if [ "${DRY_RUN:-false}" = "true" ]; then
    say "## 👀 試跑：以下內容不會真的發出"
    [ -n "$REQUIRE" ] && say "- ⛔ 強制更新：低於 **$REQUIRE** 的 App 只會看到更新畫面"
    say "- 📣 標題：**$TITLE_ZH**${TITLE_EN:+ ／ $TITLE_EN}"
    say "- 內容：$BODY_ZH"
    [ -n "$BODY_EN" ] && say "- English：$BODY_EN"
    case "$AUDIENCE" in tester) who="只給測試手機" ;; guest) who="沒登入的訪客" ;; free) who="登入但沒訂閱" ;; plus) who="Premium 訂閱者" ;; *) who="所有人" ;; esac
    case "$LINK" in "") button="沒有按鈕" ;; update) button="請大家更新" ;; plus) button="打開訂閱頁" ;; *) button="打開 $LINK" ;; esac
    say "- 👥 給誰看：$who${below_version:+（只給 $BELOW 以前的版本）}"
    say "- 🔘 按鈕：$button"
    say "- 🔔 推播：$([ "$PUSH" = true ] && echo 會推播 || echo 不推播)"
    say "- ⏳ 留：$([ "$DAYS" = 0 ] && echo 直到手動下架 || echo "$DAYS 天")"
    say ""
    say "確認沒問題：再按一次 Run workflow，**取消勾選「👀 只預覽」**，就會真的發出。"
    exit 0
  fi
  if [ -n "$REQUIRE" ]; then
    parse "$REQUIRE"
    requirement=$(jq -n --arg v "$VERSION" --arg b "$BUILD" --arg mz "${BODY_ZH:0:300}" --arg me "${BODY_EN:0:300}" \
      '{min_version: $v, min_build: (if $b == "" then null else ($b | tonumber) end), message_zh: $mz, message_en: $me}')
    reply=$(call -X POST "$rest/update_requirements" -d "$requirement")
    [ "$(code_of "$reply")" = "201" ] || { echo "::error::The forced update failed: $(body_of "$reply")"; exit 1; }
    say "⛔ 已設定強制更新：低於 $REQUIRE 的 App，下次打開或回到 App 時只會看到更新畫面。"
    say "要解除：執行「🧹 下架公告／解除強制更新」，選「解除強制更新」。"
  fi
  ends=null
  if [ "$DAYS" != "0" ]; then ends="\"$(date -u -d "+$DAYS days" +%Y-%m-%dT%H:%M:%SZ)\""; fi
  body=$(jq -n --arg tz "$TITLE_ZH" --arg bz "$BODY_ZH" --arg te "$TITLE_EN" --arg be "$BODY_EN" \
    --arg aud "$AUDIENCE" --arg link "$LINK" --arg lz "$LINK_ZH" --arg le "$LINK_EN" --argjson ends "$ends" \
    --argjson push "$PUSH" --arg bv "$below_version" --arg bb "$below_build" \
    '{title_zh: $tz, body_zh: $bz, title_en: $te, body_en: $be, audience: $aud, ends_at: $ends, push: $push,
      link: (if $link == "" then null else $link end), link_label_zh: $lz, link_label_en: $le,
      below_version: (if $bv == "" then null else $bv end),
      below_build: (if $bb == "" then null else ($bb | tonumber) end)}')
  reply=$(call -X POST "$rest/announcements" -d "$body")
  body_of "$reply" | jq -c '.[0] | {id, audience, below_version, title_zh, ends_at, push}' || true
  [ "$(code_of "$reply")" = "201" ] || { echo "::error::Posting failed with HTTP $(code_of "$reply")"; exit 1; }
  say "📣 公告已發出：每個人下次打開或回到 App 時，會全螢幕看到一次。"
  if [ "$PUSH" = "true" ]; then
    id=$(body_of "$reply" | jq -r '.[0].id')
    pushed=$(curl -sS -w '\n%{http_code}' -X POST "https://$PROJECT_REF.supabase.co/functions/v1/broadcast-push" \
      -H 'Content-Type: application/json' -d "{\"id\":\"$id\"}")
    say "🔔 推播結果：$(body_of "$pushed" | jq -r '"送出 \(.sent // 0) 台，失敗 \(.failed // 0) 台"' 2>/dev/null || body_of "$pushed")"
    [ "$(code_of "$pushed")" = "200" ] || { echo "::error::The push was not sent; the in-app message is posted"; exit 1; }
  fi
  ;;
esac
