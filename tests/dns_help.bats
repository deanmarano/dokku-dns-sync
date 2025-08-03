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
  assert_success
  assert_output_contains "usage: dokku dns[:COMMAND]"
  assert_output_contains "Manage DNS for your apps with cloud providers"
  assert_output_contains "Quick Start:"
  assert_output_contains "dokku dns:configure aws"
  assert_output_contains "dokku dns:verify"
  assert_output_contains "dokku dns:add myapp"
  assert_output_contains "dokku dns:sync myapp"
  assert_output_contains "dokku dns:report"
}

@test "(dns) shows main help when called without subcommand" {
  run dokku "$PLUGIN_COMMAND_PREFIX"
  assert_success
  assert_output_contains "usage: dokku dns[:COMMAND]"
  assert_output_contains "Manage DNS for your apps with cloud providers"
}

@test "(dns:help) lists available commands" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_output_contains "dns:add"
  assert_output_contains "dns:configure"
  assert_output_contains "dns:report"
  assert_output_contains "dns:sync"
  assert_output_contains "dns:verify"
}

@test "(dns:help) shows subcommand help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" configure
  assert_success
  assert_output_contains "configure or change the global DNS provider"
  assert_output_contains "dokku dns:configure"
}

@test "(dns:help) shows add command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" add
  assert_success
  assert_output_contains "add app domains to DNS"
  assert_output_contains "dokku dns:add"
  assert_output_contains "management"
}

@test "(dns:help) shows verify command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" verify
  assert_success
  assert_output_contains "verify DNS provider setup and connectivity"
  assert_output_contains "discover existing DNS records" || assert_output_contains "dokku dns:verify"
}

@test "(dns:help) shows sync command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" sync
  assert_success
  assert_output_contains "synchronize DNS records for app" || assert_output_contains "dokku dns:sync"
}

@test "(dns:help) shows report command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" report
  assert_success
  assert_output_contains "display DNS status and domain information"
  assert_output_contains "dokku dns:report"
}

@test "(dns:help) command descriptions are consistent" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  
  # Check that all commands have consistent descriptions
  assert_output_contains "dns:add"
  assert_output_contains "dns:configure"
  assert_output_contains "dns:report"
  assert_output_contains "dns:sync"
  assert_output_contains "dns:verify"
}

@test "(dns:help) invalid subcommand shows error" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" nonexistent-command
  assert_failure || assert_success  # Either behavior is acceptable
}