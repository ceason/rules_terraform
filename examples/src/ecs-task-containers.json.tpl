[
  {
    "name": "server",
    "image": "{{embedded_reference :push_py_image}}",
    "essential": true,
    "environment": [
       {"name": "CUSTOM_SERVER_MESSAGE", "value": "${CUSTOM_SERVER_MESSAGE}"}
    ],
    "portMappings": [
      {
        "containerPort": 8080
      }
    ]
  }
]