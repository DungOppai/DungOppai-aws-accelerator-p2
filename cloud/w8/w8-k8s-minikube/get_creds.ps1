# Read the query JSON from standard input (passed by Terraform)
$jsonInput = [Console]::In.ReadToEnd()
if (-not $jsonInput) {
    Write-Error "No input JSON received on stdin."
    exit 1
}

$query = ConvertFrom-Json $jsonInput
$HostIP = $query.host
$PrivateKeyPem = $query.private_key

if (-not $HostIP -or -not $PrivateKeyPem) {
    Write-Error "Missing required parameters 'host' or 'private_key' in JSON input."
    exit 1
}

# Define a unique temp key path using the current process ID to prevent collisions
$tempKeyPath = Join-Path $env:TEMP "temp_ec2_key_$($pid).pem"

try {
    # Write private key to a temporary file
    Set-Content -Path $tempKeyPath -Value $PrivateKeyPem -NoNewline
    
    # Restrict permissions on Windows for SSH to accept the key (equivalent to chmod 600)
    icacls.exe $tempKeyPath /inheritance:r | Out-Null
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    icacls.exe $tempKeyPath /grant:r "${username}:F" | Out-Null

    # Wait for minikube credentials to be ready on the EC2 instance
    # 60 attempts * 10 seconds = 10 minutes maximum wait time
    $maxAttempts = 60
    $attempt = 0
    $credentialsReady = $false
    
    while ($attempt -lt $maxAttempts) {
        # Check if Minikube is fully started, proxy is active, and credentials exist
        $checkCommand = "test -f ~/.minikube/ca.crt && test -f ~/.minikube/profiles/minikube/client.crt && test -f ~/.minikube/profiles/minikube/client.key && systemctl is-active k8s-api-proxy.service >/dev/null 2>&1 && sudo -u ubuntu kubectl get nodes >/dev/null 2>&1 && echo 'READY'"
        
        # Execute ssh command (disable host key checking, quiet mode)
        $result = ssh -q -i $tempKeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$HostIP $checkCommand 2>$null
        
        if ($result -eq "READY") {
            $credentialsReady = $true
            break
        }
        
        $attempt++
        Start-Sleep -Seconds 10
    }

    if (-not $credentialsReady) {
        Write-Error "Timeout waiting for Minikube credentials on EC2 instance. Check user-data logs at /var/log/user-data.log on EC2."
        exit 1
    }

    # Fetch the credentials
    $ca = ssh -q -i $tempKeyPath -o StrictHostKeyChecking=no ubuntu@$HostIP "cat ~/.minikube/ca.crt"
    $cert = ssh -q -i $tempKeyPath -o StrictHostKeyChecking=no ubuntu@$HostIP "cat ~/.minikube/profiles/minikube/client.crt"
    $key = ssh -q -i $tempKeyPath -o StrictHostKeyChecking=no ubuntu@$HostIP "cat ~/.minikube/profiles/minikube/client.key"

    # Format as single-line string with newline characters
    $ca_clean = ($ca -join "`n")
    $cert_clean = ($cert -join "`n")
    $key_clean = ($key -join "`n")

    # Output as JSON for Terraform's external data source
    $output = @{
        ca   = $ca_clean
        cert = $cert_clean
        key  = $key_clean
    } | ConvertTo-Json -Compress

    Write-Output $output
}
finally {
    # Clean up the private key file
    if (Test-Path $tempKeyPath) {
        Remove-Item $tempKeyPath -Force
    }
}
