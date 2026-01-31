#!/bin/bash

# Adiciona o diretório local de binários ao PATH para encontrar o comando 'oci'
export PATH=$PATH:$HOME/.local/bin
export OCI_CLI_CONFIG_FILE=$(pwd)/oci_config

# --- CONFIGURAÇÃO ---
# Substitua pelo OCID do seu Stack (começa com ocid1.ormstack...)
STACK_ID="ocid1.ormstack.oc1.sa-saopaulo-1.amaaaaaalycxb2yav53ioifnrixqdrikfwh4h2lpskyxew56vctizzi376bq" 
WAIT_TIME=60 # Segundos para esperar entre tentativas
# --------------------

echo "Iniciando automação para o Stack: $STACK_ID"

while true; do
    echo "----------------------------------------------------------------"
    echo "Tentando provisionar instância em: $(date)"

    # Tenta criar um Job de "Apply".
    JOB_ID=$(oci resource-manager job create-apply-job --stack-id $STACK_ID --execution-plan-strategy AUTO_APPROVED --query data.id --raw-output 2> error.log)

    # CORREÇÃO: Verifica se a variável JOB_ID está vazia (string de tamanho zero)
    if [ -z "$JOB_ID" ]; then
        echo "Erro ao criar o Job. Verifique se o OCID do Stack está correto ou se há permissão."
        echo "Aguardando antes de tentar novamente..."
        sleep $WAIT_TIME
        continue
    fi

    echo "Job criado: $JOB_ID. Monitorando status..."

    # Loop interno para esperar o Job terminar
    while true; do
        # Pega o status atual do Job
        STATUS=$(oci resource-manager job get --job-id $JOB_ID --query 'data."lifecycle-state"' --raw-output 2>/dev/null)

        # CORREÇÃO: Compara o status com os retornos padrão da Oracle Cloud
        if [ "$STATUS" == "SUCCEEDED" ]; then
            echo "✅ SUCESSO! A instância foi provisionada!"
            echo "Verifique o console em 'Compute > Instances'."
            
            # Tenta enviar notificação por email
            if [ -f "send_email.py" ]; then
                echo "Enviando notificação por email..."
                python3 send_email.py "OCI Provisioning Success" "A instância foi provisionada com sucesso! Verifique o console da Oracle Cloud."
            else
                echo "Script de email não encontrado, pulando notificação."
            fi

            exit 0
        elif [ "$STATUS" == "FAILED" ]; then
            echo "❌ Falha: Provavelmente 'Out of host capacity' (Sem estoque)."
            break # Sai do loop interno para tentar criar um novo job
        elif [ "$STATUS" == "CANCELED" ]; then
            echo "⚠️ Job cancelado manualmente."
            break
        elif [ "$STATUS" == "ACCEPTED" ] || [ "$STATUS" == "IN_PROGRESS" ]; then
            # O Job ainda está rodando, apenas espera
            echo "Status: $STATUS - Aguardando..."
            sleep 10
        else
            # Caso a API falhe em retornar o status temporariamente
            echo "Status desconhecido ($STATUS). Tentando novamente..."
            sleep 10
        fi
    done

    echo "Aguardando $WAIT_TIME segundos antes da próxima tentativa..."
    sleep $WAIT_TIME
done
