#!/usr/bin/env bats
load test_helper

# Test AWS backend functions in isolation
@test "(aws backend) dns_backend_aws_get_hosted_zone_id function exists" {
  source ../backends/aws
  # Check that the function is defined
  run declare -f dns_backend_aws_get_hosted_zone_id
  assert_success
}

@test "(aws backend) dns_backend_aws_validate_credentials function exists" {
  source ../backends/aws
  # Check that the function is defined
  run declare -f dns_backend_aws_validate_credentials
  assert_success
}

@test "(aws backend) dns_backend_aws_setup_env function exists" {
  source ../backends/aws
  # Check that the function is defined  
  run declare -f dns_backend_aws_setup_env
  assert_success
}

@test "(aws backend) dns_backend_aws_create_record function exists" {
  source ../backends/aws
  # Check that the function is defined
  run declare -f dns_backend_aws_create_record
  assert_success
}

@test "(aws backend) dns_backend_aws_sync_app function exists" {
  source ../backends/aws
  # Check that the function is defined
  run declare -f dns_backend_aws_sync_app
  assert_success
}

# Test backend validation without external dependencies
@test "(aws backend) validates aws-cli dependency" {
  # Mock dokku_log_fail function
  function dokku_log_fail() { echo "$1"; exit 1; }
  export -f dokku_log_fail
  
  source ../backends/aws
  
  # Mock command to simulate aws-cli not being available
  function command() { 
    if [[ "$2" == "aws" ]]; then
      return 1
    fi
    /usr/bin/command "$@"
  }
  export -f command
  
  # Should fail when aws-cli is not available
  run dns_backend_aws_validate_credentials "test-service"
  assert_failure
  assert_contains "$output" "aws-cli is not installed"
}

# Test subdomain parsing logic
@test "(aws backend) hosted zone parsing handles subdomains" {
  # Mock required functions
  function dokku_log_fail() { echo "$1"; exit 1; }
  export -f dokku_log_fail
  
  source ../backends/aws
  
  # Mock aws command to simulate hosted zone lookup
  function aws() {
    case "$*" in
      *"HostedZones[?Name=='app.example.com.']"*)
        echo ""  # No direct match
        ;;
      *"HostedZones[?Name=='example.com.']"*)
        echo "/hostedzone/Z123456789"  # Parent domain match
        ;;
      *)
        echo ""
        ;;
    esac
  }
  export -f aws
  
  # Test that it finds parent domain's hosted zone
  run dns_backend_aws_get_hosted_zone_id "app.example.com"
  assert_success
  assert_equal "Z123456789" "$output"
}