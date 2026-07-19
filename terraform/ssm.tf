resource "aws_ssm_document" "readiness" {
  name            = "self-healing-fleet-readiness"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Bootstrap readiness check: poll the instance's local /health endpoint before it's allowed to go InService."
    parameters = {
      InstanceId = {
        type        = "String"
        description = "Instance to verify."
      }
    }
    mainSteps = [
      {
        name           = "WaitForHealthy"
        action         = "aws:runCommand"
        timeoutSeconds = 120
        onFailure      = "Abort"
        inputs = {
          DocumentName = "AWS-RunShellScript"
          InstanceIds  = ["{{ InstanceId }}"]
          Parameters = {
            commands = [
              "for i in $(seq 1 20); do curl -sf http://localhost/health >/dev/null && exit 0; sleep 5; done; echo 'readiness check failed' >&2; exit 1"
            ]
          }
        }
      }
    ]
  })
}
