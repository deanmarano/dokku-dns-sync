#!/usr/bin/env bash
export DOKKU_LIB_ROOT="/var/lib/dokku"
export PATH="$PATH:$DOKKU_LIB_ROOT/plugins/available/dns/subcommands"
source "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/config"

# DNS plugin test helper functions
setup_dns_provider() {
  local provider="${1:-aws}"
  dokku dns:configure "$provider" >/dev/null 2>&1 || true
}

cleanup_dns_data() {
  rm -rf "$PLUGIN_DATA_ROOT" >/dev/null 2>&1 || true
}

create_test_app() {
  local app_name="$1"
  dokku apps:create "$app_name" >/dev/null 2>&1 || true
}

add_test_domains() {
  local app_name="$1"
  shift
  local domains=("$@")
  
  for domain in "${domains[@]}"; do
    dokku domains:add "$app_name" "$domain" >/dev/null 2>&1 || true
  done
}

cleanup_test_app() {
  local app_name="$1"
  dokku apps:destroy "$app_name" --force >/dev/null 2>&1 || true
}

flunk() {
  {
    if [ "$#" -eq 0 ]; then
      cat -
    else
      echo "$*"
    fi
  }
  return 1
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    {
      echo "expected: $1"
      echo "actual:   $2"
    } | flunk
  fi
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
assert_exit_status() {
  assert_equal "$1" "$status"
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
# shellcheck disable=SC2120
assert_success() {
  if [ "$status" -ne 0 ]; then
    flunk "command failed with exit status $status"
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    flunk "expected failed exit status"
  elif [[ "$#" -gt 0 ]]; then
    assert_output "$1"
  fi
}

assert_exists() {
  if [ ! -f "$1" ]; then
    flunk "expected file to exist: $1"
  fi
}

assert_contains() {
  if [[ "$1" != *"$2"* ]]; then
    flunk "expected $2 to be in: $1"
  fi
}

# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output() {
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="$1"
  fi
  assert_equal "$expected" "$output"
}

# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output_contains() {
  local input="$output"
  local expected="$1"
  local count="${2:-1}"
  local found=0
  until [ "${input/$expected/}" = "$input" ]; do
    input="${input/$expected/}"
    found=$((found + 1))
  done
  assert_equal "$count" "$found"
}
