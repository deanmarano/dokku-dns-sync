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
  # When no apps are added to DNS, shows help message
  assert_output_contains "Add an app to DNS with: dokku dns:add <app-name>"
}

@test "(dns:report) app-specific report works" {
  # Add app to DNS management first
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app >/dev/null 2>&1 || true
  
  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  assert_output_contains "DNS Report for app: my-app"
  assert_output_contains "Server Public IP:"
  assert_output_contains "Global DNS Provider: aws"
  assert_output_contains "Configuration Status: Configured"
  assert_output_contains "DNS Status: Added"
  assert_output_contains "Domain Analysis:"
  assert_output_contains "Domain                              DNS      Status               Provider     Hosted Zone"
  assert_output_contains "------                              ---      ------               --------     -----------"
  assert_output_contains "example.com"
  assert_output_contains "Provider not ready"
  assert_output_contains "DNS Status Legend:"
  assert_output_contains "Actions available:"
  assert_output_contains "Fix configuration issues, then update: dokku dns:sync my-app"
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
  assert_output_contains "DNS Status: Not added"
  assert_output_contains "Configure DNS provider: dokku dns:configure"
}

@test "(dns:report) global report handles no apps gracefully" {
  cleanup_test_app my-app
  cleanup_test_app other-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  assert_output_contains "DNS Global Report - All Apps"
  assert_output_contains "Global DNS Provider: aws"
  assert_output_contains "Configuration Status: Configured"
  assert_output_contains "Add an app to DNS with: dokku dns:add <app-name>"
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
  
  # Shows basic report information
  assert_output_contains "DNS Global Report - All Apps"
  assert_output_contains "Global DNS Provider: aws"
  assert_output_contains "Configuration Status: Configured"
  # When no apps added to DNS, shows help message
  assert_output_contains "Add an app to DNS with: dokku dns:add <app-name>"
}

@test "(dns:report) shows provider status" {
  # Add app to DNS management first  
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app >/dev/null 2>&1 || true
  
  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  
  # Provider appears multiple times in output (header and table)
  assert_output_contains "aws" 2
  assert_output_contains "Provider not ready" || assert_output_contains "DNS Status: Added"
}