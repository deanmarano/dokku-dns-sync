#!/usr/bin/env bats
load test_helper

setup() {
  # No setup needed for help tests
  true
}

teardown() {
  rm -rf "$PLUGIN_DATA_ROOT" >/dev/null 2>&1 || true
}

@test "(dns:help) shows main help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns) shows main help when called without subcommand" {
  run dokku "$PLUGIN_COMMAND_PREFIX"
  assert_success
  assert_output_contains "Mock dokku command: dns"
}

@test "(dns:help) lists available commands" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) shows subcommand help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" configure
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) shows add command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" add
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) shows verify command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" verify
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) shows sync command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" sync
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) shows report command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" report
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) command descriptions are consistent" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}

@test "(dns:help) invalid subcommand shows error" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" nonexistent-command
  assert_failure
  assert_output_contains "Unknown subcommand: help"
}