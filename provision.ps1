
$ErrorActionPreference = "Stop"

# Configuration
$STACK_ID = "ocid1.ormstack.oc1.sa-saopaulo-1.amaaaaaalycxb2yav53ioifnrixqdrikfwh4h2lpskyxew56vctizzi376bq"
$WAIT_TIME = 60

# Set OCI Config File to the one in the current directory
$env:OCI_CLI_CONFIG_FILE = Join-Path (Get-Location) "oci_config"
$env:SUPPRESS_LABEL_WARNING = "True"

Write-Host "Iniciando automação para o Stack: $STACK_ID"

while ($true) {
    Write-Host "----------------------------------------------------------------"
    Write-Host "Tentando provisionar instância em: $(Get-Date)"

    # Create Apply Job
    $ErrorOutput = "$PWD\oci_error.log"
    try {
        $JOB_ID = oci resource-manager job create-apply-job --stack-id $STACK_ID --execution-plan-strategy AUTO_APPROVED --query data.id --raw-output 2> $ErrorOutput
    } catch {
        Write-Host "Erro na execução do comando (provavelmente temporário):" -ForegroundColor Yellow
        if (Test-Path $ErrorOutput) {
            Get-Content $ErrorOutput | Write-Host -ForegroundColor Red
        }
        $JOB_ID = $null
    }

    if ([string]::IsNullOrWhiteSpace($JOB_ID)) {
        Write-Host "Erro ao criar o Job. Verifique se o OCID do Stack está correto ou se há permissão."
        if (Test-Path $ErrorOutput) {
            Write-Host "Detalhes do erro:" -ForegroundColor Red
            Get-Content $ErrorOutput | Write-Host -ForegroundColor Red
        }
        Write-Host "Aguardando antes de tentar novamente..."
        Start-Sleep -Seconds $WAIT_TIME
        continue
    }

    Write-Host "Job criado: $JOB_ID. Monitorando status..."

    while ($true) {
        # Pega o status atual do Job
        # CORREÇÃO: Escaping de aspas para PowerShell e OCI CLI (Windows requer \")
        $STATUS = oci resource-manager job get --job-id $JOB_ID --query 'data.\"lifecycle-state\"' --raw-output 2>$null

        if ($STATUS -eq "SUCCEEDED") {
            Write-Host "✅ SUCESSO! A instância foi provisionada!"
            Write-Host "Verifique o console em 'Compute > Instances'."
            exit 0
        } elseif ($STATUS -eq "FAILED") {
            Write-Host "❌ Falha: Provavelmente 'Out of host capacity' (Sem estoque)."
            break
        } elseif ($STATUS -eq "CANCELED") {
            Write-Host "⚠️ Job cancelado manualmente."
            break
        } elseif ($STATUS -eq "ACCEPTED" -or $STATUS -eq "IN_PROGRESS") {
            Write-Host "Status: $STATUS - Aguardando..."
            Start-Sleep -Seconds 10
        } else {
            Write-Host "Status desconhecido ($STATUS). Tentando novamente..."
            Start-Sleep -Seconds 10
        }
    }

    Write-Host "Aguardando $WAIT_TIME segundos antes da próxima tentativa..."
    Start-Sleep -Seconds $WAIT_TIME
}
