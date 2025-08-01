#!/usr/bin/env bats
load test_helper

setup() {
  dokku "$PLUGIN_COMMAND_PREFIX:create" l >&2 || true
}

teardown() {
  dokku --force "$PLUGIN_COMMAND_PREFIX:destroy" l >&2 || true
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) success with aws" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend" l aws
  assert_success
  assert_contains "${lines[*]}" "Backend set to 'aws' for service: l"
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) success with cloudflare" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend" l cloudflare
  assert_success
  assert_contains "${lines[*]}" "Backend set to 'cloudflare' for service: l"
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend"
  assert_failure
  assert_contains "${lines[*]}" "Please specify a service name"
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) error when backend is missing" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend" l
  assert_failure
  assert_contains "${lines[*]}" "Please specify a backend"
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) error when backend is invalid" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend" l invalid
  assert_failure
  assert_contains "${lines[*]}" "Invalid backend 'invalid'"
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) error when service does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend" nonexistent aws
  assert_failure
  assert_contains "${lines[*]}" "service does not exist"
}

@test "($PLUGIN_COMMAND_PREFIX:set-backend) creates backend file" {
  run dokku "$PLUGIN_COMMAND_PREFIX:set-backend" l aws
  assert_success
  assert_exists "$PLUGIN_DATA_ROOT/l/BACKEND"
  assert_equal "aws" "$(cat "$PLUGIN_DATA_ROOT/l/BACKEND")"
}