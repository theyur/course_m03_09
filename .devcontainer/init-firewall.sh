#!/bin/bash
# init-firewall.sh - default-deny OUTBOUND firewall for a Claude Code .NET devcontainer.
# Run from devcontainer postStartCommand.
# Requires NET_ADMIN and NET_RAW capabilities.
#
# Design:
# - outbound IPv4/IPv6 traffic is denied by default
# - inbound traffic is allowed so Rider/devcontainer port forwarding and Swagger work
# - DNS is limited to resolvers from /etc/resolv.conf
# - Claude/Anthropic, NuGet, and GitHub endpoints are whitelisted
# - GitHub git CIDRs are fetched from api.github.com/meta and validated

set -euo pipefail

# 1. Reset rules. Restrict OUTPUT only; INPUT stays open for host -> devcontainer traffic.
iptables -F OUTPUT
iptables -F INPUT
iptables -P OUTPUT DROP
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP

ip6tables -F OUTPUT
ip6tables -F INPUT
ip6tables -P OUTPUT DROP
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD DROP

# 2. Loopback is always allowed.
iptables  -A OUTPUT -o lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# 3. Allow traffic belonging to already-established connections.
iptables  -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 4. DNS: only resolvers provided to this container.
DNS_SERVERS=$(awk '/^nameserver / {print $2}' /etc/resolv.conf | sort -u)
if [ -z "$DNS_SERVERS" ]; then
  echo "WARN: no nameserver found in /etc/resolv.conf; using Docker DNS 127.0.0.11"
  DNS_SERVERS="127.0.0.11"
fi

for dns in $DNS_SERVERS; do
  if [[ "$dns" == *:* ]]; then
    ip6tables -A OUTPUT -p udp -d "$dns" --dport 53 -j ACCEPT
    ip6tables -A OUTPUT -p tcp -d "$dns" --dport 53 -j ACCEPT
  else
    iptables -A OUTPUT -p udp -d "$dns" --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp -d "$dns" --dport 53 -j ACCEPT
  fi
done

# 5. Resolve explicitly allowed services into ipsets.
ipset destroy claude-allowed   2>/dev/null || true
ipset destroy claude-allowed-6 2>/dev/null || true
ipset create claude-allowed   hash:net family inet  hashsize 1024 maxelem 65536
ipset create claude-allowed-6 hash:net family inet6 hashsize 1024 maxelem 65536

ALLOWED_DOMAINS=(
  # Claude Code
  "api.anthropic.com"
  "statsig.anthropic.com"
  "sentry.io"

  # NuGet / dotnet restore
  "api.nuget.org"
  "www.nuget.org"
  "globalcdn.nuget.org"

  # Git / GitHub
  "api.github.com"
  "github.com"
  "objects.githubusercontent.com"
  "codeload.github.com"

  # JSON schema validation (used by Rider)
  "json-schema.org"
  "json.schemastore.org"

  # Rider's marketplace and plugin repository
  "plugins.jetbrains.com"
  "downloads.marketplace.jetbrains.com"

  # Rider's update-related endpoints
  "download.jetbrains.com"
  "download-cf.jetbrains.com"
  "www.jetbrains.com"
)

for domain in "${ALLOWED_DOMAINS[@]}"; do
  ips4=$(getent ahostsv4 "$domain" 2>/dev/null | awk '/STREAM/ {print $1}' | sort -u || true)
  for ip in $ips4; do
    ipset add claude-allowed "$ip" 2>/dev/null || true
  done

  ips6=$(getent ahostsv6 "$domain" 2>/dev/null | awk '/STREAM/ {print $1}' | sort -u || true)
  for ip in $ips6; do
    ipset add claude-allowed-6 "$ip" 2>/dev/null || true
  done

  if [ -z "$ips4" ] && [ -z "$ips6" ]; then
    echo "WARN: could not resolve $domain; skipping"
  fi
done

# 6. Temporarily allow api.github.com so we can retrieve GitHub's published git CIDRs.
gh_ip=$(getent ahostsv4 api.github.com 2>/dev/null | awk '/STREAM/ {print $1; exit}' || true)
if [ -n "$gh_ip" ]; then
  iptables -I OUTPUT 1 -d "$gh_ip" -p tcp --dport 443 -j ACCEPT

  github_cidrs=$(curl -fsS --max-time 10 https://api.github.com/meta \
    | jq -r '.git[]? | select(contains(":") | not)' \
    || true)

  cidr_re='^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$'
  for cidr in $github_cidrs; do
    if [[ "$cidr" =~ $cidr_re ]]; then
      prefix="${cidr##*/}"
      if [ "$prefix" -lt 8 ]; then
        echo "WARN: rejecting overly broad GitHub CIDR $cidr"
        continue
      fi
      ipset add claude-allowed "$cidr" 2>/dev/null || true
    else
      echo "WARN: rejecting invalid GitHub CIDR $cidr"
    fi
  done
fi

# 7. Permit HTTP(S) only to destinations in the whitelist.
iptables  -A OUTPUT -p tcp -m set --match-set claude-allowed   dst --dport 443 -j ACCEPT
iptables  -A OUTPUT -p tcp -m set --match-set claude-allowed   dst --dport 80  -j ACCEPT
ip6tables -A OUTPUT -p tcp -m set --match-set claude-allowed-6 dst --dport 443 -j ACCEPT
ip6tables -A OUTPUT -p tcp -m set --match-set claude-allowed-6 dst --dport 80  -j ACCEPT

# 8. Self-validation.
echo "=== Firewall self-validation ==="

# Anthropic's root endpoint may return a non-2xx status; connectivity/TLS success is what matters here.
if curl -sS --connect-timeout 5 --max-time 8 https://api.anthropic.com -o /dev/null; then
  echo "OK: api.anthropic.com reachable"
else
  echo "FAIL: api.anthropic.com should be reachable"
  exit 1
fi

if curl -fsS --connect-timeout 5 --max-time 8 https://api.nuget.org/v3/index.json -o /dev/null; then
  echo "OK: api.nuget.org reachable"
else
  echo "FAIL: api.nuget.org should be reachable for dotnet restore"
  exit 1
fi

if curl -fsS --connect-timeout 3 --max-time 5 https://example.com -o /dev/null 2>&1; then
  echo "FAIL: example.com should be blocked; outbound default-deny is broken"
  exit 1
else
  echo "OK: example.com blocked"
fi

if getent ahostsv6 ipv6.google.com >/dev/null 2>&1; then
  if curl -6 -fsS --connect-timeout 3 --max-time 5 https://ipv6.google.com -o /dev/null 2>&1; then
    echo "FAIL: ipv6.google.com reachable; IPv6 default-deny is broken"
    exit 1
  else
    echo "OK: IPv6 default-deny works"
  fi
fi

echo "=== Firewall ready ==="
