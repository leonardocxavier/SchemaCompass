#!/bin/bash

# ==============================================================================
# GERADOR DE MAPA DE BANCO DE DADOS v6.1 - "Zero Lógica na IA" + Anti-bug
# ==============================================================================

set -e
set -o pipefail

MYSQL_DB="NomeDoSeuBancoDeDados" # Substitua pelo nome do seu banco de dados
# Certifique-se de que o banco de dados existe e está acessível
# Você pode definir a variável MYSQL_DB como um argumento de linha de comando, se preferir

OLLAMA_MODEL="llama3.2:1b" # Modelo de IA a ser usado
# Certifique-se de que o modelo está instalado e acessível via Ollama
# Você pode alterar o modelo conforme necessário, mas certifique-se de que ele suporta prompts em
ARQUIVO_SAIDA="mapa_producao.json" # Arquivo de saída para o mapeamento
# Você pode alterar o nome do arquivo de saída conforme necessário

# --- FUNÇÃO AUXILIAR PARA IA (TAREFA FOCADA) ---
function gerar_descricao_ia() {
    local TIPO_ITEM=$1 # "Tabela" ou "Campo"
    local NOME_TABELA=$2
    local NOME_CAMPO=$3

    if [[ "$TIPO_ITEM" == "Tabela" ]]; then
        PROMPT_IA="Em uma frase curta e em português, descreva o propósito da tabela de banco de dados chamada '$NOME_TABELA'."
    else
        PROMPT_IA="Em uma frase curta e útil, descreva o propósito do campo de banco de dados chamado '$NOME_CAMPO' que pertence à tabela '$NOME_TABELA'."
    fi

    ollama run "$OLLAMA_MODEL" "$PROMPT_IA" 2>/dev/null < /dev/null | tr -d '"' | paste -sd ' ' -
}

# --- SCRIPT PRINCIPAL ---
echo "Iniciando o mapeamento de produção (Lógica Zero na IA)... Saída em: $ARQUIVO_SAIDA"
> "$ARQUIVO_SAIDA"

mysql "$MYSQL_DB" -N -e "SHOW TABLES" | while read -r TABELA; do
    echo "--------------------------------------------------"
    echo "Processando tabela: $TABELA"

    # --- ETAPA 1: Extração de Metadados ---
    echo "   -> Coletando metadados brutos do INFORMATION_SCHEMA..."

    # Coleta colunas
    COLUNAS_RAW=$(
        mysql "$MYSQL_DB" -B -e "
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = '$MYSQL_DB' AND TABLE_NAME = '$TABELA';
        " | tail -n +2
    )
    if [[ -n "$COLUNAS_RAW" ]]; then
        COLUNAS_JSON_BASE=$(echo "$COLUNAS_RAW" | jq -R -s '
            split("\n") | .[0:-1] | map(split("\t")) | map({
                nome: .[0],
                tipo_dado: .[1],
                obrigatorio: (.[2] == "NO"),
                descricao: null,
                relacionamento: null
            })
        ')
    else
        COLUNAS_JSON_BASE="[]"
    fi

    # Se não houver colunas, pula a tabela
    if [[ "$COLUNAS_JSON_BASE" == "[]" ]]; then
        echo "Tabela '$TABELA' não possui colunas. Pulando..."
        continue
    fi

    # Coleta FKs
    FKS_RAW=$(
        mysql "$MYSQL_DB" -B -e "
            SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA = '$MYSQL_DB' AND TABLE_NAME = '$TABELA' AND REFERENCED_TABLE_NAME IS NOT NULL;
        " | tail -n +2
    )
    if [[ -n "$FKS_RAW" ]]; then
        FKS_JSON=$(echo "$FKS_RAW" | jq -R -s '
            split("\n") | .[0:-1] | map(split("\t")) | map({
                campo: .[0],
                tabela_referenciada: .[1],
                campo_referenciado: .[2]
            })
        ')
    else
        FKS_JSON="[]"
    fi

    # --- ETAPA 2: Montagem da Estrutura Base com 'jq' ---
    echo "   -> Montando a estrutura JSON base com jq..."
    CAMPOS_COM_RELACOES=$(jq -n --argjson colunas "$COLUNAS_JSON_BASE" --argjson fks "$FKS_JSON" '
        $colunas | map(
            .relacionamento = ($fks | map(select(.campo == .nome)) | .[0] // null)
        ) |
        map(
            if .relacionamento != null then
                .relacionamento |= {tabela: .tabela_referenciada, campo: .campo_referenciado}
            else
                .
            end
        )
    ')

    # --- ETAPA 3: Enriquecimento Granular com IA ---
    echo "   -> Enriquecendo cada campo com descrições da IA..."

    CAMPOS_ENRIQUECIDOS="[]"
    for COLUNA_OBJ in $(echo "$CAMPOS_COM_RELACOES" | jq -c '.[]'); do
        NOME_CAMPO=$(echo "$COLUNA_OBJ" | jq -r '.nome')
        echo "      -> Gerando descrição para o campo: $NOME_CAMPO"
        DESCRICAO_IA=$(gerar_descricao_ia "Campo" "$TABELA" "$NOME_CAMPO")
        COLUNA_ENRIQUECIDA=$(echo "$COLUNA_OBJ" | jq --arg desc "$DESCRICAO_IA" '.descricao = $desc')
        CAMPOS_ENRIQUECIDOS=$(echo "$CAMPOS_ENRIQUECIDOS" | jq ". + [$COLUNA_ENRIQUECIDA]")
    done

   # --- ETAPA 4: Montagem Final (VERSÃO CORRIGIDA) ---
echo "   -> Montando o objeto JSON final..."

CAMPOS_OBRIGATORIOS=$(echo "$CAMPOS_ENRIQUECIDOS" | jq '[.[] | select(.obrigatorio == true) | .nome]')
DEPENDENCIAS=$(echo "$FKS_JSON" | jq 'map({campo: .campo, aponta_para: "\(.tabela_referenciada).\(.campo_referenciado)"})')

LABEL_IA=$(gerar_descricao_ia "Tabela" "$TABELA" "")
DESCRICAO_IA=$(gerar_descricao_ia "Tabela" "$TABELA" "")
TIPO_IA="cadastro" # Ou outra lógica para definir o tipo

echo "DEBUG: tabela = $TABELA"
echo "DEBUG: label = $LABEL_IA"
echo "DEBUG: descricao = $DESCRICAO_IA"
echo "DEBUG: tipo = $TIPO_IA"
echo "DEBUG: campos_obrigatorios = $CAMPOS_OBRIGATORIOS"
echo "DEBUG: campos = $CAMPOS_ENRIQUECIDOS"
echo "DEBUG: dependencias = $DEPENDENCIAS"

JSON_FINAL=$(jq -n \
    --arg tabela "$TABELA" \
    --arg label "$LABEL_IA" \
    --arg descricao "$DESCRICAO_IA" \
    --arg tipo "$TIPO_IA" \
    --argjson campos_obrigatorios "$CAMPOS_OBRIGATORIOS" \
    --argjson campos "$CAMPOS_ENRIQUECIDOS" \
    --argjson dependencias "$DEPENDENCIAS" \
    '{
        "Tabela": $tabela,
        "label": $label,
        "descricao": $descricao,
        "tipo": $tipo,
        "campos_obrigatorios": $campos_obrigatorios,
        "campos": $campos,
        "dependencias": $dependencias
    }'
)

    echo "$JSON_FINAL" >> "$ARQUIVO_SAIDA"
    echo "   -> Mapeamento de produção para a tabela '$TABELA' concluído."

done

echo "--------------------------------------------------"
echo "MAPEAMENTO FINALIZADO. O resultado está em $ARQUIVO_SAIDA"
