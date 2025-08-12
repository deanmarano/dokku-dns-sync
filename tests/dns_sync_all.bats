#!/usr/bin/env bats
load test_helper

setup() {
  global_setup
  create_app
}

teardown() {
  global_teardown
}

@test "(dns:sync-all) error when there are no managed apps" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  assert_success
  assert_output_contains "No apps are currently managed by DNS"
}

@test "(dns:sync-all) error when no provider configured" {
  # Add an app to DNS management  
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  # Remove provider configuration
  rm -f "$PLUGIN_DATA_ROOT/PROVIDER" 2>/dev/null || true
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  assert_failure
  assert_output_contains "No DNS provider configured"
}

@test "(dns:sync-all) syncs all managed apps" {
  # Configure provider
  dokku "$PLUGIN_COMMAND_PREFIX:configure" aws
  
  # Add multiple apps
  create_service "test-app-1"
  create_service "test-app-2"
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  dokku "$PLUGIN_COMMAND_PREFIX:add" test-app-1
  dokku "$PLUGIN_COMMAND_PREFIX:add" test-app-2
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  
  # Should show attempt to sync all apps
  assert_output_contains "Synchronizing DNS records for 3 managed app"
  assert_output_contains "Syncing DNS records for app: my-app"
  assert_output_contains "Syncing DNS records for app: test-app-1"
  assert_output_contains "Syncing DNS records for app: test-app-2"
}

@test "(dns:sync-all) handles missing apps gracefully" {
  # Configure provider
  dokku "$PLUGIN_COMMAND_PREFIX:configure" aws
  
  # Add app to DNS
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  
  # Manually add a non-existent app to LINKS file
  echo "nonexistent-app" >> "$PLUGIN_DATA_ROOT/LINKS"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  
  # Should handle missing app gracefully
  assert_output_contains "App 'nonexistent-app' no longer exists, skipping"
  assert_output_contains "Remove from DNS: dokku dns:remove nonexistent-app"
}

@test "(dns:sync-all) shows summary with mixed results" {
  # Configure provider  
  dokku "$PLUGIN_COMMAND_PREFIX:configure" aws
  
  # Add apps
  create_service "working-app"
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  dokku "$PLUGIN_COMMAND_PREFIX:add" working-app
  
  # Add non-existent app to simulate failure
  echo "missing-app" >> "$PLUGIN_DATA_ROOT/LINKS"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  
  # Should show summary
  assert_output_contains "DNS Sync Summary"
  assert_output_contains "Successfully synced:"
  assert_output_contains "Failed to sync:"
}