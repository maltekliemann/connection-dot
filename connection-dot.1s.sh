#!/bin/bash
# <swiftbar.title>Connectivity</swiftbar.title>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

# Every run loads Apple's captive portal test page, the check macOS itself uses.
# The time to connect is the ping. The last few results are kept to spot a slow
# or unstable connection. Only when the page fails twice in a row do we probe
# router, internet and DNS to find where it breaks.

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

GREEN='#30D158' YELLOW='#FFD60A' RED='#FF453A'
SLOW_MS=150   # average ping above this is yellow
MAX_LOST=1    # more failed checks than this in the window is yellow
WINDOW=10     # number of checks kept, one per second
state=${TMPDIR:-/tmp}/connectivity-bar.state

show() {
  printf '● | color=%s\n---\n%s | color=%s\n' "$1" "$2" "$1"
  shift 2
  if (($#)); then echo ---; printf '%s\n' "$@"; fi
  exit 0
}

# Probe IPv4 alongside the page: Apple may answer over IPv6 while IPv4 is down.
nc -z -G1 -w1 1.1.1.1 443 >/dev/null 2>&1 & p_v4=$!
out=$(curl -s -m1 -H 'Cache-Control: no-cache' \
  -w '\n%{http_code} %{remote_ip} %{time_namelookup} %{time_connect}' \
  http://captive.apple.com/hotspot-detect.html)
body=${out%$'\n'*}
set -- ${out##*$'\n'}
code=$1 ip=$2
ping_ms=$(( (10#${4/./} - 10#${3/./}) / 1000 ))
wait "$p_v4"; v4=$?

ok=0 v4_down=0
if [[ $body == *Success* ]]; then
  ok=1
  if ((v4 != 0)) && [[ $ip == *:* ]] && ! nc -z -G1 -w1 8.8.8.8 443 >/dev/null 2>&1; then
    ok=0 v4_down=1
  fi
fi

# History of the last checks: ping in ms, or x for a failure.
hist=()
[[ -r $state ]] && read -r -a hist <"$state"
prev=; ((${#hist[@]})) && prev=${hist[${#hist[@]}-1]}
if ((ok)); then hist+=("$ping_ms"); else hist+=(x); fi
((${#hist[@]} > WINDOW)) && hist=("${hist[@]: -WINDOW}")
echo "${hist[*]}" >"$state"

lost=0 sum=0 n=0
for s in "${hist[@]}"; do
  if [[ $s == x ]]; then ((lost++)); else ((sum += s, n++)); fi
done
avg=0; ((n)) && avg=$((sum / n))

# A single failure isn't an outage: judge the connection by its recent history.
if ((ok)) || [[ $prev != x ]]; then
  stats=("Average ping $avg ms" "Failed $lost of last ${#hist[@]} checks")
  ((ok)) && stats=("Ping $ping_ms ms" "${stats[@]}")
  ((lost > MAX_LOST)) && show "$YELLOW" "Unstable connection" "${stats[@]}"
  ((avg > SLOW_MS)) && show "$YELLOW" "Slow connection" "${stats[@]}"
  show "$GREEN" "Connected" "${stats[@]}"
fi

((v4_down)) && show "$YELLOW" "IPv4 not working, IPv6 OK"

# Failed twice in a row. Probe everything in parallel to locate the break.
gw=$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')
[[ -n $gw ]] && { ping -c1 -t1 "$gw" >/dev/null 2>&1 & p_router=$!; }
nc -z -G1 -w1 1.1.1.1 443 >/dev/null 2>&1 & p_cf=$!
nc -z -G1 -w1 8.8.8.8 443 >/dev/null 2>&1 & p_google=$!
dig +time=1 +tries=1 apple.com 2>/dev/null | grep -q 'status: NOERROR' & p_dns=$!

router=–
[[ -n $p_router ]] && { wait "$p_router" && router=✓ || router=✗; }
wait "$p_cf"; cf=$?
wait "$p_google"; google=$?
((cf == 0 || google == 0)) && internet=✓ || internet=✗
wait "$p_dns" && dns=✓ || dns=✗
[[ $code == 000 ]] && page="no answer" || page="HTTP $code instead"

details=(
  "$router Router (${gw:-no gateway})"
  "$internet Internet"
  "$dns DNS"
  "Apple test page: $page"
)

# Something other than Apple answered: a login page, or a block or error page.
[[ $code != 000 ]] && show "$YELLOW" "Captive portal or blocked page" "${details[@]}"
if [[ $internet == ✓ ]]; then
  [[ $dns == ✗ ]] && show "$YELLOW" "DNS not working" "${details[@]}"
  show "$YELLOW" "Internet reachable, web requests fail" "${details[@]}"
fi
[[ -z $gw ]] && show "$RED" "No network (or VPN down)" "${details[@]}"
[[ $router == ✓ ]] && show "$RED" "Router OK, internet down" "${details[@]}"
show "$RED" "Router unreachable" "${details[@]}"
