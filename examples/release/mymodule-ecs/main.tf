

resource random_string password {
  length  = 5
  special = false
  upper   = false
}

variable custom_server_message {
  default     = "Hello, world!"
  description = "The server will respond to all HTTP requests with this message"
}

