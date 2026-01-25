# OCI Automation

Este projeto contém scripts para automatizar o provisionamento de recursos no Oracle Cloud Infrastructure (OCI) utilizando o OCI CLI e Resource Manager Stacks.

## Estrutura do Projeto

* `provision.ps1`: Script em PowerShell para Windows.
* `provision.sh`: Script em Bash para Linux/macOS.
* `install_oci.py`: Script Python para instalação do OCI CLI.
* `oci_config`: Arquivo de configuração local.
* `oci_config_linux`: Arquivo de configuração adaptado para o servidor remoto.
* `oci_automation.service`: Arquivo de serviço Systemd para execução contínua no Linux.
* `oci_keys/`: Chaves de API (segredadas).

## Configuração Local (Windows)

1. **Chaves**: Coloque suas chaves em `oci_keys/`.
2. **Config**: Ajuste `oci_config` com o caminho correto das chaves (ex: `c:\Users\...`).
3. **Execução**:

    ```powershell
    ./provision.ps1
    ```

    *Nota: Se houver erro de política de execução, rode: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`.*

## Configuração Remota (Linux / Servidor)

O projeto está configurado para rodar como um serviço Systemd no servidor (ex: `144.22.206.150`), garantindo execução 24/7.

### Monitoramento de Logs

Para ver o que o script está fazendo dentro do servidor, você precisa acessar via SSH e consultar os logs do sistema.

1. **Acesse o servidor**:

    ```bash
    ssh -i id_ed25519 opc@144.22.206.150
    ```

2. **Verifique os logs do serviço**:
    Execute o comando abaixo para ver os logs em tempo real (role para cima/baixo se necessário):

    ```bash
    sudo journalctl -u oci_automation -f
    ```

    * `-u oci_automation`: Filtra os logs do nosso serviço.
    * `-f`: "Follow" (acompanha em tempo real). Pressione `Ctrl+C` para sair.

3. **Verifique o status do serviço**:

    ```bash
    sudo systemctl status oci_automation
    ```

### Parar/Iniciar a Automação

* Parar: `sudo systemctl stop oci_automation`
* Iniciar: `sudo systemctl start oci_automation`
* Reiniciar: `sudo systemctl restart oci_automation`
