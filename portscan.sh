#!/bin/bash

# ==========================================
# Automação de Reconhecimento de Portas
# Autor: Seu Nome (ou GitHub User)
# Descrição: Realiza scans TCP/UDP em estágios
# ==========================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verifica se é root (necessário para -sU e -sS)
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Por favor, execute como root (sudo).${NC}"
  exit 1
fi

nmap_args=""

# Loop para capturar flags
while getopts ":g:" opt; do
    case "$opt" in
        g)  nmap_args+=" -g $OPTARG";;
        \?) echo "Opção inválida: -$OPTARG"; exit 1;;
        :)  echo "Faltou argumento da opção -$OPTARG"; exit 1;;
    esac
done

shift $((OPTIND - 1))

# Verifica alvo
if [ -z "$1" ]; then
    echo -e "${YELLOW}Modo de uso: $0 [-g <source_port>] <ip_alvo>${NC}"
    echo -e "Exemplo: $0 -g 53 192.168.0.20"
    exit 1
fi

TARGET=$1
OUTPUT_DIR="scan_${TARGET}"
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}[*] Iniciando varredura em: ${TARGET}${NC}"
echo -e "${BLUE}[*] Resultados salvos em: ${OUTPUT_DIR}/${NC}\n"

# Função para extrair portas do arquivo grepable/normal do nmap
# Uso: extract_ports <arquivo_nmap>
extract_ports() {
    local file=$1
    # Lógica limpa: Pega linhas com /tcp ou /udp, remove filtradas, pega o número da porta, troca quebra de linha por vírgula
    grep -E '^[0-9]+/(tcp|udp)' "$file" | grep 'open' | cut -d '/' -f 1 | tr '\n' ',' | sed 's/,$//'
}

# Função genérica de scan
# Uso: run_scan <nome_etapa> <flags_nmap> <arquivo_saida>
run_scan() {
    local stage_name=$2
    local flags=$3
    local output_file="${OUTPUT_DIR}/$4"

    echo -e "${GREEN}[+] Escaneando: ${stage_name}...${NC}"
    
    # Executa o scan
    nmap $flags $nmap_args -oN "$output_file" "$TARGET" > /dev/null
    
    # Extrai portas
    ports=$(extract_ports "$output_file")
    
    if [ -n "$ports" ]; then
        echo -e "${YELLOW}    Portas encontradas: ${ports}${NC}"
        echo "$ports" > "${output_file}.ports"
    else
        echo -e "${RED}    Nenhuma porta encontrada nesta etapa.${NC}"
    fi
}

# --- ESTÁGIO 1: TCP Rápido (Top 1000) ---
# Dica: Pulei o top 100, vamos direto pro 1000 que é o padrão e rápido o suficiente
run_scan "TCP Top 1000" "--top-ports 1000 --open -sS -T4 -Pn" "tcp_top1000"

# --- ESTÁGIO 2: UDP Rápido (Top 10) ---
run_scan "UDP Top 10" "-sU --top-ports 10 --open -T4 -Pn" "udp_top10"

# --- ESTÁGIO 3: TCP Completo (Todas as portas) ---
echo -e "\n${GREEN}[+] Iniciando Scan TCP Completo (Isso pode demorar)...${NC}"
run_scan "TCP Full Port" "-p- --open -sS -T4 -Pn" "tcp_full"

# --- ESTÁGIO 4: Detecção de Versão (Service Scan) ---
if [ -f "${OUTPUT_DIR}/tcp_full.ports" ]; then
    ports=$(cat "${OUTPUT_DIR}/tcp_full.ports")
    echo -e "\n${GREEN}[+] Enumerando versões nas portas TCP: ${ports}${NC}"
    nmap -sV -sC -p"$ports" $nmap_args -oN "${OUTPUT_DIR}/tcp_services.txt" "$TARGET"
else
    echo -e "${RED}[!] Pulo Enumeração TCP (sem portas abertas).${NC}"
fi

# --- ESTÁGIO 5: UDP Completo (Top 100) ---
# UDP Full demora muito, top 100 é um bom compromisso
run_scan "UDP Top 100" "-sU --top-ports 100 --open -T4 -Pn" "udp_top100"

if [ -f "${OUTPUT_DIR}/udp_top100.ports" ]; then
    ports=$(cat "${OUTPUT_DIR}/udp_top100.ports")
    echo -e "\n${GREEN}[+] Enumerando versões nas portas UDP: ${ports}${NC}"
    nmap -sV -p"$ports" $nmap_args -oN "${OUTPUT_DIR}/udp_services.txt" "$TARGET"
fi

# --- Relatório Final ---
echo -e "\n${BLUE}[*] Escaneamento Completo!${NC}"
echo -e "Confira os detalhes em: ${OUTPUT_DIR}/tcp_services.txt"