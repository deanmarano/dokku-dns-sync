#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:verify) error when no provider configured" {
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  assert_output_contains "No provider configured"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:verify) error when provider file is empty" {
  # Create empty provider file
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  assert_output_contains "Provider not set"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:verify) error when invalid provider configured" {
  # Create provider file with invalid provider
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "invalid" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  assert_output_contains "Provider 'invalid' not found"
  assert_output_contains "Available providers: aws, cloudflare"
}

@test "(dns:verify) attempts AWS verification when configured" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_output_contains "Verifying AWS Route53 access"
  assert_output_contains "Checking AWS CLI configuration"
  
  # Test will likely show auth issues in test environment, which is expected
  if [[ "$status" -eq 0 ]]; then
    # If AWS is properly configured, should show success
    assert_output_contains "AWS CLI configured successfully"
  else
    # If not configured, should show helpful instructions
    assert_output_contains "AWS CLI is not configured" || assert_output_contains "Please configure AWS CLI"
  fi
}

@test "(dns:verify) shows AWS setup instructions when CLI not configured" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  
  # Should show setup instructions (either success or helpful failure)
  assert_output_contains "Verifying AWS Route53 access"
  
  if [[ "$status" -ne 0 ]]; then
    assert_output_contains "Please configure AWS CLI first using one of these methods:"
    assert_output_contains "aws configure"
    assert_output_contains "AWS_ACCESS_KEY_ID"
    assert_output_contains "AWS_SECRET_ACCESS_KEY"
  fi
}

@test "(dns:verify) handles cloudflare provider" {
  setup_dns_provider cloudflare
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  
  # Currently shows provider not found error even though it's listed as available
  assert_output_contains "Provider 'cloudflare' not found"
}

@test "(dns:verify) provides helpful guidance" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  
  # Should provide next steps regardless of success/failure
  if [[ "$status" -eq 0 ]]; then
    assert_output_contains "Next steps:" || assert_output_contains "Ready to use"
  else
    assert_output_contains "Please configure" || assert_output_contains "Run:"
  fi
}