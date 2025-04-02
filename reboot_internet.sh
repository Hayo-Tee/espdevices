#!/bin/bash

# ��������� �������
ROUTER_IP="10.10.1.1"
USERNAME="user"       # �����
PASSWORD="user"    # ������
LOGIN_URL="http://$ROUTER_IP/login.htm"
REBOOT_URL_BASE="http://$ROUTER_IP/maintenance/saveandreboot_tl.xgi"

# ������� ��� ���������� MD5-����
md5_hash() {
    echo -n "$1" | md5sum | awk '{print $1}'
}

# �������� ����������� �������
ping -q -c 1 "$ROUTER_IP" > /dev/null || { echo "������ ����������"; exit 1; }

# ��������� MD5-��� ������
PASSWORD_HASH=$(md5_hash "$PASSWORD")

# ��� 1: �����������
# ���������� POST-������ � ������� � ����� ������
# -L: ������� ����������������
# --user-agent: ��������� User-Agent
curl -X POST \
     -L \
     --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
     -d "f_username=$USERNAME&f_password=$PASSWORD_HASH&f_currURL=$LOGIN_URL" \
     -c cookies.txt \
     -o login_response.html \
     "$LOGIN_URL"

# ��� 2: ��������� cookies.txt
if [ ! -s cookies.txt ]; then
    echo "������: cookies.txt ������. ��������� �����/������."
    exit 1
fi

# ��� 3: ��������� �������� /status/st_deviceinfo_tl.htm, ����� ����� sessionKey
curl -L \
     --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
     -b cookies.txt \
     -o device_info.html \
     "http://$ROUTER_IP/status/st_deviceinfo_tl.htm"

# ��� 4: ���������� sessionKey
# ������������, ��� sessionKey ����� ���� � URL ��� � HTML
SESSION_KEY=$(grep -oP 'sessionKey=\K\d+' device_info.html)

if [ -z "$SESSION_KEY" ]; then
    # ���� sessionKey �� ������, ������� ��������� �������� ������������
    curl -L \
         --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
         -b cookies.txt \
         -o reboot_page.html \
         "http://$ROUTER_IP/maintenance/mt_system_tl.htm"
    SESSION_KEY=$(grep -oP 'sessionKey=\K\d+' reboot_page.html)
fi

if [ -z "$SESSION_KEY" ]; then
    echo "�� ������� ������� sessionKey. ��������� ��������� ��������."
    exit 1
fi

# ��� 5: ��������� URL ��� ������������
REBOOT_URL="$REBOOT_URL_BASE?sessionKey=$SESSION_KEY"

# ��� 6: �������� ������� �� ������������
curl -L \
     --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
     -b cookies.txt \
     "$REBOOT_URL"

if [ $? -eq 0 ]; then
    echo "������� �� ������������ ����������"
else
    echo "������ ��� �������� �������"
fi

# ��� 7: ������� ��������� �����
rm -f cookies.txt login_response.html device_info.html reboot_page.html