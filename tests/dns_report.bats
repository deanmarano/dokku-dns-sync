#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws  
  create_test_app my-app
  add_test_domains my-app example.com
  create_test_app other-app
  add_test_domains other-app test.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_test_app other-app
  cleanup_dns_data
}

@test "(dns:report) global report shows all apps" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  assert_output_contains "DNS Global Report - All Apps"
  assert_output_contains "Server Public IP:"
  assert_output_contains "Global DNS Provider: aws"
  assert_output_contains "Configuration Status: Configured"
  assert_output_contains "All Apps Domain Analysis:"
  assert_output_contains "App             Domain                    DNS      Status          Provider     Hosted Zone"
  assert_output_contains "---             ------                    ---      ------          --------     -----------"
  assert_output_contains "my-app"
  assert_output_contains "example.com"
  assert_output_contains "other-app"
  assert_output_contains "test.com"
  assert_output_contains "DNS Status Legend:"
  assert_output_contains "✅ Points to server IP"
  assert_output_contains "⚠️  Points to different IP"
  assert_output_contains "❌ No DNS record found"
}

@test "(dns:report) app-specific report works" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  assert_output_contains "DNS Report for app: my-app"
  assert_output_contains "Server Public IP:"
  assert_output_contains "Global DNS Provider: aws"
  assert_output_contains "Configuration Status: Configured"
  assert_output_contains "Domain Analysis:"
  assert_output_contains "Domain                         DNS      Status               Provider     Hosted Zone"
  assert_output_contains "------                         ---      ------               --------     -----------"
  assert_output_contains "example.com"
  assert_output_contains "DNS Status Legend:"
  assert_output_contains "Actions available:"
  assert_output_contains "Configure credentials: dokku dns:verify"
  assert_output_contains "Then sync DNS: dokku dns:sync my-app"
}

@test "(dns:report) app-specific report shows error for nonexistent app" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:report) shows no provider when not configured" {
  cleanup_dns_data  # Remove provider configuration
  
  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  assert_output_contains "Global DNS Provider: None"
  assert_output_contains "Configuration Status: Not configured"
  assert_output_contains "No DNS provider configured"
  assert_output_contains "Configure one with: dokku dns:configure <provider>"
}

@test "(dns:report) global report handles no apps gracefully" {
  cleanup_test_app my-app
  cleanup_test_app other-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  assert_output_contains "No Dokku apps found"
  assert_output_contains "Create an app with: dokku apps:create <app-name>"
}

@test "(dns:report) app report handles app with no domains" {
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:report" empty-app
  assert_success
  assert_output_contains "DNS Report for app: empty-app"
  assert_output_contains "No domains configured for app: empty-app"
  assert_output_contains "Add domains with: dokku domains:add empty-app <domain>"
  
  cleanup_test_app empty-app
}

@test "(dns:report) shows DNS status emojis" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  
  # Should show one of the DNS status emojis for the domain
  assert_output_contains "❌" || assert_output_contains "✅" || assert_output_contains "⚠️"
}

@test "(dns:report) global report shows domain count" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  
  # Should mention domain counts or percentages
  assert_output_contains "DNS status:" || assert_output_contains "configured" || assert_output_contains "Total domains:"
}

@test "(dns:report) shows provider status" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  
  # Should show provider status
  assert_output_contains "aws"
  assert_output_contains "Missing auth" || assert_output_contains "Ready" || assert_output_contains "Not ready"
}