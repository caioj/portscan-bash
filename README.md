# Auto Recon Script

Script de automação para reconhecimento de portas TCP e UDP utilizando Nmap. O script executa varreduras em estágios para garantir resultados rápidos iniciais seguidos de varreduras profundas.

## Funcionalidades
- Scan TCP Top 1000
- Scan UDP Top 10
- Scan TCP Full Port (65535 portas)
- Enumeração de Versões (-sV) e Scripts Padrão (-sC) nas portas encontradas
- Organização automática de arquivos por alvo

## Como usar

```bash
chmod +x scan.sh
sudo ./scan.sh <IP>
# Ou com bypass de firewall (source port)
sudo ./scan.sh -g 53 <IP>
