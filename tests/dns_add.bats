#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  create_test_app my-app
  add_test_domains my-app example.com api.example.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
}

@test "(dns:add) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add"
  assert_failure
  assert_output_contains "Please specify an app name"
}

@test "(dns:add) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:add) success with existing app shows domain status table" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  assert_success
  assert_output_contains "Adding domains for app 'my-app' to DNS management"
  assert_output_contains "Domain Status Table for app 'my-app'"
  assert_output_contains "Domain                         Status   Enabled         Provider        Hosted Zone"
  assert_output_contains "example.com"
  assert_output_contains "api.example.com"
  assert_output_contains "Yes"  # Enabled column
  assert_output_contains "aws"  # Provider column
  assert_output_contains "Status Legend:"
  assert_output_contains "✅ Points to server IP"
  assert_output_contains "⚠️  Points to different IP"
  assert_output_contains "❌ No DNS record found"
  assert_output_contains "Domains have been registered for DNS management"
  assert_output_contains "Next step: dokku dns:sync my-app"
}

@test "(dns:add) success with specific domains shows table" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app example.com
  assert_success
  assert_output_contains "Adding specified domains for app 'my-app': example.com"
  assert_output_contains "Domain Status Table for app 'my-app'"
  assert_output_contains "example.com"
  assert_output_contains "Yes"  # Enabled
  assert_output_contains "aws"  # Provider
  assert_output_contains "Status Legend:"
}

@test "(dns:add) success with multiple specific domains" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app example.com api.example.com
  assert_success
  assert_output_contains "Adding specified domains for app 'my-app': example.com api.example.com"
  assert_output_contains "Domain Status Table for app 'my-app'"
  assert_output_contains "example.com"
  assert_output_contains "api.example.com"
  assert_output_contains "aws"
}

@test "(dns:add) handles app with no domains gracefully" {
  # Create app with no domains
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:add" empty-app
  assert_failure
  assert_output_contains "No domains found for app 'empty-app'"
  assert_output_contains "Add domains first with: dokku domains:add empty-app <domain>"
  
  # Clean up
  cleanup_test_app empty-app
}

@test "(dns:add) fails when no provider configured" {
  cleanup_dns_data  # Remove provider configuration
  
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  assert_failure
  assert_output_contains "No DNS provider configured"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:add) works with single domain app" {
  # Create app with single domain
  create_test_app single-app
  add_test_domains single-app single.example.com
  
  run dokku "$PLUGIN_COMMAND_PREFIX:add" single-app
  assert_success
  assert_output_contains "Domain Status Table for app 'single-app'"
  assert_output_contains "single.example.com"
  
  cleanup_test_app single-app
}