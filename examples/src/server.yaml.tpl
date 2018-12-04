
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-server
  labels:
    app: hello-world-server
spec:
  ports:
  - {name: http-server, port: 80, targetPort: http-server}
  selector:
    app: hello-world-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-server
spec:
  replicas: 1
  selector:
    matchLabels: &podLabels
      app: hello-world-server
  template:
    metadata:
      labels: {<<: *podLabels}
    spec:
      containers:
      - name: server
        image: {{embedded_reference :push_py_image}}
        terminationMessagePolicy: FallbackToLogsOnError
        envFrom:
        - configMapRef: {name: hello-world-server, optional: false}
        ports:
        - containerPort: 8080
          name: http-server

