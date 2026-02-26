# MongoDB Atlas FULL Backup Downloader

Script automatizado para download de snapshots FULL do MongoDB Atlas
com:

-   Filtro por intervalo de datas
-   Filtro por dia da semana (1=domingo ... 7=sábado)
-   Execução automática dentro de sessão tmux
-   Download paralelo controlado
-   Controle de duplicidade (não baixa o mesmo snapshot duas vezes)
-   Validação mínima de espaço em disco
-   Configuração centralizada via arquivo YAML (download.cfg)

------------------------------------------------------------------------

## 📦 Requisitos

O script instala automaticamente, caso não estejam presentes:

-   jq
-   yq
-   tmux
-   MongoDB Atlas CLI

Sistema suportado: - Ubuntu 20.04+ - Distribuições baseadas em Debian

------------------------------------------------------------------------

## 🔐 Pré-requisito obrigatório

Você deve estar autenticado no Atlas CLI antes da execução:

    atlas auth login

E possuir permissão para: - Listar snapshots - Baixar snapshots -
Acessar o projeto informado

------------------------------------------------------------------------

## ⚙️ Arquivo de Configuração

Crie um arquivo chamado:

    download.cfg

Formato YAML:

``` yaml
project_id: "SEU_PROJECT_ID"
cluster_name: "NOME_DO_CLUSTER"

date_range:
  start: "2025-01-01"
  end: "2025-01-31"

weekday: 2          # 1=domingo ... 7=sábado
parallel: 4         # downloads simultâneos
download_dir: "./atlas_backups"
min_disk_gb: 20
```

------------------------------------------------------------------------

## 📅 Parâmetro weekday

  Valor   Dia
  ------- ---------
  1       Domingo
  2       Segunda
  3       Terça
  4       Quarta
  5       Quinta
  6       Sexta
  7       Sábado

------------------------------------------------------------------------

## 🚀 Execução

    chmod +x download.sh
    ./download.sh

O script automaticamente:

1.  Instala dependências ausentes
2.  Cria sessão tmux chamada downloadAtlasBackupXX (XX = número
    randômico 00--99)
3.  Lista snapshots FULL
4.  Filtra por data e dia da semana
5.  Valida espaço mínimo em disco
6.  Executa downloads paralelos
7.  Evita baixar arquivos já existentes
8.  Encerra a sessão tmux ao final

------------------------------------------------------------------------

## ⚡ Controle de Paralelismo

O parâmetro:

    parallel: 4

Define quantos downloads ocorrerão simultaneamente.

### Recomendação prática

  Ambiente   Paralelo sugerido
  ---------- -------------------
  2 vCPU     2--3
  4 vCPU     4--6
  8+ vCPU    6--10

Considere: - Banda de rede disponível - IOPS do disco - Tamanho médio
dos snapshots

Mais paralelismo nem sempre significa maior velocidade.

------------------------------------------------------------------------

## 🛡️ Proteções Implementadas

-   Não baixa snapshot duplicado
-   Bloqueia execução se espaço mínimo não for atingido
-   Execução resiliente via tmux
-   Controle de concorrência via xargs -P

------------------------------------------------------------------------

## 📁 Estrutura Gerada

    .
    ├── download.sh
    ├── download.cfg
    └── atlas_backups/
        ├── backup_<snapshotId>.tar.gz
        └── ...

------------------------------------------------------------------------

## ⚠️ Observações Importantes

-   Datas devem estar no formato YYYY-MM-DD
-   createdAt do Atlas é interpretado pelo sistema local
-   Não calcula tamanho total real dos snapshots antes de iniciar
-   Pode ser necessário adaptar paginação do Atlas CLI para grandes
    volumes

------------------------------------------------------------------------

## 🔧 Melhorias Futuras Possíveis

-   Cálculo real de espaço necessário via storageSizeBytes
-   Log estruturado em arquivo
-   Modo dry-run
-   Retry automático com backoff
-   Execução via cron
-   Serviço systemd
-   Upload automático para S3/NFS
-   Verificação de integridade pós-download

------------------------------------------------------------------------

## 🧠 Casos de Uso

-   Disaster Recovery (DR)
-   Compliance
-   Auditoria
-   Migração controlada
-   Backup off-platform

------------------------------------------------------------------------

## 📄 Licença

"Este projeto é licenciado sob os termos da Apache License, Versão 2.0. Consulte o arquivo LICENSE para obter mais detalhes."
