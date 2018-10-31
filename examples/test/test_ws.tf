resource random_string uniqifier {
  length  = 5
  special = false
  upper   = false
}

locals {
  test_message = "This is a custom message, configured in the test workspace! Our unique token for this run is '${random_string.uniqifier.result}'"
}


