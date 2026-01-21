# OCI Automation

Este projeto contém scripts para automatizar o provisionamento de recursos no Oracle Cloud Infrastructure (OCI) utilizando o OCI CLI e Resource Manager Stacks.

## Estrutura do Projeto

* `provision.ps1`: Script em PowerShell para Windows.
* `provision.sh`: Script em Bash para Linux/macOS.
* `install_oci.py`: Script Python para instalação do OCI CLI (caso necessário).
* `oci_config`: Arquivo de configuração local para o OCI CLI.
* `oci_keys/`: Diretório contendo as chaves de API (não versionado/não incluído no repositório público por segurança).

## Pré-requisitos

1. **OCI CLI**: Deve estar instalado e configurado no seu sistema.
    * Verifique a instalação com: `oci --version`
2. **Conta Oracle Cloud**: Uma conta ativa com permissões para gerenciar criar Jobs no Resource Manager.
3. **Stack ID**: O ID do Stack (Resource Manager) que você deseja automatizar.

## Configuração

1. **Chaves de API**:
    * Coloque sua chave privada (`oci_api_key.pem`) e pública na pasta `oci_keys/`.
    * Este diretório é ignorado pelo Git para segurança.

2. **Arquivo de Configuração (`oci_config`)**:
    * Este arquivo deve conter as credenciais do seu *tenancy*, *user* e *fingerprint*.
    * **Importante**: O caminho para o `key_file` deve ser absoluto ou ajustado conforme o seu sistema operacional.
        * **Windows**: `key_file=c:\Caminho\Para\oci_keys\oci_api_key.pem`
        * **Linux**: `key_file=/home/usuario/.../oci_keys/oci_api_key.pem`

3. **Scripts de Provisionamento**:
    * Edite `provision.ps1` (Windows) ou `provision.sh` (Linux) e atualize a variável `$STACK_ID` ou `STACK_ID` com o OCID do seu Stack.

## Uso

### Windows

Execute o script PowerShell:

```powershell
./provision.ps1
```

> **Nota**: Se você encontrar um erro de permissão ("excecution of scripts is disabled"), execute o seguinte comando para permitir scripts locais para o seu usuário:
>
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

O script tentará criar um Job de "Apply" no Stack especificado. Se falhar (ex: por falta de capacidade do host), ele aguardará e tentará novamente em loop.

### Linux / macOS

Dê permissão de execução e rode o script Bash:

```bash
chmod +x provision.sh
./provision.sh
```

## Instalação do OCI CLI (Opcional)

Se você ainda não tem o OCI CLI, pode usar o script incluído:

```bash
python install_oci.py
```
