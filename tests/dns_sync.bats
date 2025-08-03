#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  create_test_app my-app
  add_test_domains my-app example.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
}

@test "(dns:sync) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync"
  assert_failure
  assert_output_contains "Please specify an app name"
}

@test "(dns:sync) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:sync) error when no provider configured" {
  cleanup_dns_data  # Remove provider configuration
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_failure
  assert_output_contains "No DNS provider configured"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:sync) error when provider file is empty" {
  # Create empty provider file
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_failure
  assert_output_contains "DNS provider not set"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:sync) error when invalid provider configured" {
  # Create provider file with invalid provider
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "invalid" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_failure
  assert_output_contains "Unknown provider: invalid"
  assert_output_contains "Supported providers: aws, cloudflare"
}

@test "(dns:sync) attempts AWS sync when configured" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  
  # This will likely fail due to AWS auth issues in test environment
  # but should show it's attempting to sync
  assert_output_contains "example.com" # Should mention the domain
  
  if [[ "$status" -eq 0 ]]; then
    # If AWS is properly configured, should show success
    assert_output_contains "DNS sync completed successfully" || assert_output_contains "Updated DNS record"
  else
    # If not configured, should show helpful auth error
    assert_output_contains "AWS CLI is not configured" || assert_output_contains "credentials are invalid"
    assert_output_contains "Run: dokku dns:verify"
  fi
}

@test "(dns:sync) handles app with no domains" {
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" empty-app
  assert_failure
  assert_output_contains "No domains found for app 'empty-app'"
  assert_output_contains "Add domains first with: dokku domains:add empty-app <domain>"
  
  cleanup_test_app empty-app
}

@test "(dns:sync) shows helpful error when AWS not accessible" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  
  # In test environment, likely to fail with auth issues
  if [[ "$status" -ne 0 ]]; then
    assert_output_contains "AWS CLI is not configured" || assert_output_contains "credentials"
    assert_output_contains "Run: dokku dns:verify"
  fi
}

@test "(dns:sync) attempts sync with multiple domains" {
  add_test_domains my-app api.example.com admin.example.com
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  
  # Should mention all domains being processed  
  assert_output_contains "example.com"
  assert_output_contains "api.example.com"
  assert_output_contains "admin.example.com"
}