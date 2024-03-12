# Encode a string to Base64 for Kubernetes configuration

$ENCODE = Read-Host "String to Base64 Encode"
[convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ENCODE))

