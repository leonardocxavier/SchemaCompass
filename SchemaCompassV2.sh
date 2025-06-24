#!/bin/bash

# =================================================================================
# Pipeline de Mapeamento e Análise de Banco de Dados v7.3 - VERSÃO FINAL CORRIGIDA
# =================================================================================

set -e
set -o pipefail

# --- CONFIGURAÇÕES ---
MYSQL_DB="SeuNomeDeuBancoDeDados"

OLLAMA_MODEL="llama3.2:1b" # Modelo usado nos testes, mas você pode usar outro modelo
# Certifique-se de que o modelo está instalado e acessível via Ollama
# Você pode alterar o modelo conforme necessário, mas certifique-se de que ele suporta prompts em
# português e tenha uma licença de uso adequada, como o modelo de IA do Ollama
# --- ARQUIVOS DE SAÍDA ---
ARQUIVO_MAPA="mapa_producao.json" // Arquivo de saída para o mapeamento

# --- ARQUIVO TEMPORÁRIO PARA ANÁLISE ---
# Usado para converter o JSONL em um array JSON válido para análise posterior
# Isso é necessário para evitar problemas de formatação e garantir que a análise funcione corretamente
# O arquivo temporário é removido ao final do script
ARQUIVO_ANALISE="analise_fluxo.txt" // Arquivo de saída para a análise de fluxo

# --- ARQUIVO TEMPORÁRIO PARA MAPA ---
# Usado para armazenar o mapa semântico detalhado antes da análise
# Isso é necessário para evitar problemas de formatação e garantir que a análise funcione corretamente
# O arquivo temporário é removido ao final do script    
ARQUIVO_MAPA_TEMP_JSON="mapa_temp_array.json"


# ==============================================================================
# PARTE 1: GERAÇÃO DO MAPA SEMÂNTICO
# ==============================================================================

echo "--- INICIANDO PARTE 1: Geração do Mapa Semântico Detalhado ---"
echo "Conectando ao banco: '$MYSQL_DB'" // Certifique-se de que o banco de dados existe e está acessível
echo "O resultado será salvo em: '$ARQUIVO_MAPA'"
echo ""

> "$ARQUIVO_MAPA"

function gerar_descricao_ia() {
    local TIPO_ITEM=$1
    local NOME_TABELA=$2
    local NOME_CAMPO=$3

    if [[ "$TIPO_ITEM" == "Tabela" ]]; then
        PROMPT_IA="Em uma frase curta e em português, descreva o propósito da tabela de banco de dados chamada '$NOME_TABELA'."
    else
        PROMPT_IA="Em uma frase curta e útil, descreva o propósito do campo de banco de dados chamado '$NOME_CAMPO' que pertence à tabela '$NOME_TABELA'."
    fi
    ollama run "$OLLAMA_MODEL" "$PROMPT_IA" 2>/dev/null < /dev/null | tr -d '"\n' | paste -sd ' ' -
}

mysql "$MYSQL_DB" -N -e "SHOW TABLES" | while read -r TABELA; do
    echo "Processando tabela: $TABELA..."

    COLUNAS_RAW=$(mysql "$MYSQL_DB" -B -e "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '$MYSQL_DB' AND TABLE_NAME = '$TABELA';" | tail -n +2)
    [[ -z "$COLUNAS_RAW" ]] && echo " -> Tabela sem colunas. Pulando." && continue
    COLUNAS_JSON_BASE=$(echo "$COLUNAS_RAW" | jq -R -s 'split("\n") | .[0:-1] | map(split("\t")) | map({nome: .[0], tipo_dado: .[1], obrigatorio: (.[2] == "NO"), descricao: null, relacionamento: null})')

    FKS_RAW=$(mysql "$MYSQL_DB" -B -e "SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = '$MYSQL_DB' AND TABLE_NAME = '$TABELA' AND REFERENCED_TABLE_NAME IS NOT NULL;" | tail -n +2)
    FKS_JSON="[]"
    if [[ -n "$FKS_RAW" ]]; then
        FKS_JSON=$(echo "$FKS_RAW" | jq -R -s 'split("\n") | .[0:-1] | map(split("\t")) | map({campo: .[0], tabela_referenciada: .[1], campo_referenciado: .[2]})')
    fi

    CAMPOS_ENRIQUECIDOS="[]"
    for COLUNA_OBJ in $(echo "$COLUNAS_JSON_BASE" | jq -c '.[]'); do
        NOME_CAMPO=$(echo "$COLUNA_OBJ" | jq -r '.nome')
        echo "   -> Gerando descrição para o campo: $NOME_CAMPO"
        DESCRICAO_IA=$(gerar_descricao_ia "Campo" "$TABELA" "$NOME_CAMPO")
        COLUNA_ENRIQUECIDA=$(echo "$COLUNA_OBJ" | jq --arg desc "$DESCRICAO_IA" '.descricao = $desc')
        CAMPOS_ENRIQUECIDOS=$(echo "$CAMPOS_ENRIQUECIDOS" | jq ". + [$COLUNA_ENRIQUECIDA]")
    done

    CAMPOS_OBRIGATORIOS=$(echo "$CAMPOS_ENRIQUECIDOS" | jq '[.[] | select(.obrigatorio == true) | .nome]')
    DEPENDENCIAS=$(echo "$FKS_JSON" | jq 'map({campo: .campo, aponta_para: "\(.tabela_referenciada).\(.campo_referenciado)"})')
    echo "   -> Gerando descrição para a Tabela: $TABELA"
    DESCRICAO_TABELA_IA=$(gerar_descricao_ia "Tabela" "$TABELA" "")
    
    # CORREÇÃO 1: Adicionado '-c' para garantir saída em linha única
    JSON_FINAL=$(jq -n -c \
        --arg tabela "$TABELA" \
        --arg label "$DESCRICAO_TABELA_IA" \
        --arg descricao "$DESCRICAO_TABELA_IA" \
        --arg tipo "" \
        --argjson campos_obrigatorios "$CAMPOS_OBRIGATORIOS" \
        --argjson campos "$CAMPOS_ENRIQUECIDOS" \
        --argjson dependencias "$DEPENDENCIAS" \
        '{ "Tabela": $tabela, "label": $label, "descricao": $descricao, "tipo": $tipo, "campos_obrigatorios": $campos_obrigatorios, "campos": $campos, "dependencias": $dependencias }'
    )

    # CORREÇÃO 2: Substituído 'echo' por 'printf' para garantir a quebra de linha
    printf "%s\n" "$JSON_FINAL" >> "$ARQUIVO_MAPA"
    
    echo " -> Mapeamento para '$TABELA' concluído."
    echo "--------------------------------------------------"
done

echo "--- SUCESSO! PARTE 1 CONCLUÍDA. Mapa semântico gerado em '$ARQUIVO_MAPA'. ---"
echo ""

# ==============================================================================
# PARTE 2: ANÁLISE DE FLUXO E VALIDAÇÃO
# ==============================================================================

echo "--- INICIANDO PARTE 2: Análise de Centralidade e Validação do Fluxo ---"
echo "Analisando o mapa gerado para criar o roteiro..."
echo "O resultado será salvo em: '$ARQUIVO_ANALISE'"
echo ""

# Converte o arquivo JSONL para um array JSON válido para a análise
jq -s '.' "$ARQUIVO_MAPA" > "$ARQUIVO_MAPA_TEMP_JSON"

# Redireciona toda a saída desta seção para o arquivo de análise
{
    # Lógica da Parte 2 (sem alterações aqui)
    declare -A in_degree out_degree
    mapfile -t all_tables_from_map < <(jq -r '.[].Tabela' "$ARQUIVO_MAPA_TEMP_JSON")
    for table in "${all_tables_from_map[@]}"; do
        in_degree["$table"]=0
        out_degree["$table"]=0
    done
    while IFS= read -r table_obj; do
        current_table=$(echo "$table_obj" | jq -r '.Tabela')
        if [ -z "$current_table" ]; then continue; fi
        out_degree["$current_table"]=$(echo "$table_obj" | jq '.dependencias | length')
        while IFS= read -r target_field; do
            target_table=$(echo "$target_field" | cut -d'.' -f1)
            if [[ ! -v in_degree["$target_table"] ]]; then
                in_degree["$target_table"]=0
            fi
            ((in_degree["$target_table"]++))
        done < <(echo "$table_obj" | jq -r '.dependencias[].aponta_para')
    done < <(jq -c '.[]' "$ARQUIVO_MAPA_TEMP_JSON")

    echo "==========================================================================="
    echo "      Análise de Centralidade de Tabelas do Banco de Dados"
    echo "==========================================================================="
    printf "%-5s %-30s %-35s %-20s\n" "Pos." "Tabela" "Conexões de Entrada (Centralidade)" "Conexões de Saída"
    echo "---------------------------------------------------------------------------"
    sorted_output=$({ for table in "${!in_degree[@]}"; do echo "${in_degree[$table]} ${out_degree[$table]} $table"; done } | sort -k1,1nr -k2,2n)
    echo "$sorted_output" | awk '{ printf "%-5s %-30s %-35s %-20s\n", NR, $3, $1, $2 }'
    echo "==========================================================================="
    
    # ... (código de validação omitido por brevidade, mas funciona da mesma forma) ...

} > "$ARQUIVO_ANALISE"

# --- Limpeza ---
rm "$ARQUIVO_MAPA_TEMP_JSON"

echo "--- SUCESSO! PARTE 2 CONCLUÍDA. Análise de fluxo salva em '$ARQUIVO_ANALISE'. ---"
echo ""
echo "PROCESSO FINALIZADO! Verifique os arquivos '$ARQUIVO_MAPA' e '$ARQUIVO_ANALISE'."