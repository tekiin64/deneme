#!/bin/bash

ZABBIX_URL="http://10.31.0.106/api_jsonrpc.php"
AUTH_TOKEN="de1cd0d3a86eddd0eaf03323082f29a061e1daf2959c3a8c6243bb9581da96f3"
JSON_FILE="sekerbank_ses_sw.json"
HOST_COUNT=$(jq '. | length' $JSON_FILE)

zabbix_api_request() {
    local request_data="$1"
    local response=$(curl -s -X POST -H "Content-Type: application/json-rpc" -d "$request_data" "$ZABBIX_URL")
    echo "$response"
}

for i in $(seq 0 $(($HOST_COUNT - 1))); do
    HOST_NAME=$(jq -r ".[$i].host" $JSON_FILE)

    # Host'un interface ID'sini almak için hostinterface.get kullan
    INTERFACE_RESPONSE=$(zabbix_api_request '{
        "jsonrpc": "2.0",
        "method": "hostinterface.get",
        "params": {
            "filter": {
                "host": ["'"$HOST_NAME"'"]
            }
        },
        "auth": "'"$AUTH_TOKEN"'",
        "id": 1
    }')

    INTERFACE_ID=$(echo "$INTERFACE_RESPONSE" | jq -r '.result[0].interfaceid')

    if [ -z "$INTERFACE_ID" ] || [ "$INTERFACE_ID" == "null" ]; then
        echo "Host arayüzü bulunamadı: $HOST_NAME"
    else
        # Host'un portunu 161 olarak güncelle
        UPDATE_INTERFACE_RESPONSE=$(zabbix_api_request '{
            "jsonrpc": "2.0",
            "method": "hostinterface.update",
            "params": {
                "interfaceid": "'"$INTERFACE_ID"'",
                "port": "161"
            },
            "auth": "'"$AUTH_TOKEN"'",
            "id": 1
        }')

        UPDATED_INTERFACE_ID=$(echo "$UPDATE_INTERFACE_RESPONSE" | jq -r '.result.interfaceids[0]')
        if [ -z "$UPDATED_INTERFACE_ID" ] || [ "$UPDATED_INTERFACE_ID" == "null" ]; then
            echo "Host arayüzü güncelleme başarısız: $HOST_NAME"
        else
            echo "Host arayüzü başarıyla güncellendi: $HOST_NAME, Interface ID: $UPDATED_INTERFACE_ID"
        fi
    fi
done
