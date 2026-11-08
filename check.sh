#!/usr/bin/env bash
# Сторож Grigmi: проверяет сайты снаружи. Падение — после двух неудач подряд с паузой 20 с (не дёргаемся от одного сбоя).
# Пишет в Telegram только когда состояние меняется: «упало» и «снова работает». Состояние — файл state (кэш Actions).
set -uo pipefail
CHECKS=(
  "Grigmi — регистрация|https://grigmi.com/start|Grigmi"
  "Grigmi — сайт клиента (шаблон)|https://tpl-sezon.grigmi.com/|<html"
  "Grigmi — вход в админку|https://tpl-sezon--admin.grigmi.com/admin/login|<html"
  "Сайт студии|https://grig-studio.ge/|<html"
  "Админка студии|https://my.grig-studio.ge/admin/login|<html"
)
probe() { # url, слово на странице
  local body code
  body=$(curl -sS -L --max-time 25 -A "GrigmiWatch/1.0" -w $'\n%{http_code}' "$1" 2>&1) || return 1
  code=${body##*$'\n'}
  [ "$code" = "200" ] && grep -q "$2" <<<"$body"
}
touch state; down=()
for c in "${CHECKS[@]}"; do
  IFS='|' read -r name url word <<<"$c"
  probe "$url" "$word" || { sleep 20; probe "$url" "$word"; } || down+=("$name")
done
now=$(printf '%s\n' "${down[@]:-}" | sed '/^$/d' | sort)
was=$(sort state)
send() {
  [ -n "${TG_TOKEN:-}" ] && curl -fsS --max-time 15 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "text=$1" >/dev/null || echo "не отправилось: $1"
}
while IFS= read -r n; do [ -n "$n" ] && ! grep -qxF "$n" <<<"$was" && send "⛔ Не открывается: $n. Проверка снаружи, $(date -u +%H:%M) UTC."; done <<<"$now"
while IFS= read -r n; do [ -n "$n" ] && ! grep -qxF "$n" <<<"$now" && send "✅ Снова работает: $n."; done <<<"$was"
printf '%s\n' "$now" > state
echo "Не открываются: ${#down[@]}"; printf '  %s\n' "${down[@]:-}"
