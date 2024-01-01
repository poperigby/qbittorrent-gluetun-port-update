trap "echo Caught SIGTERM, exiting; exit 0" TERM

echo "Starting qbittorent-gluetun-port-update"
echo "Config:"
echo "QBITTORRENT_WEBUI_HOST=$QBITTORRENT_WEBUI_HOST"
echo "QBITTORRENT_WEBUI_PORT=$QBITTORRENT_WEBUI_PORT"
echo "QBITTORRENT_WEBUI_USERNAME=$QBITTORRENT_WEBUI_USERNAME"
CENSORED_QBITTORRENT_WEBUI_PASSWORD=$(echo $QBITTORRENT_WEBUI_PASSWORD | sed 's/./*/g')
echo "QBITTORRENT_WEBUI_PASSWORD=$CENSORED_QBITTORRENT_WEBUI_PASSWORD"
echo "GLUETUN_CONTROL_HOST=$GLUETUN_CONTROL_HOST"
echo "GLUETUN_CONTROL_PORT=$GLUETUN_CONTROL_PORT"
echo "INITIAL_DELAY_SEC=$INITIAL_DELAY_SEC"
echo "CHECK_INTERVAL_SEC=$CHECK_INTERVAL_SEC"
echo "ERROR_INTERVAL_SEC=$ERROR_INTERVAL_SEC"
echo "ERROR_INTERVAL_COUNT=$ERROR_INTERVAL_COUNT"

qbittorrent_base_url="http://$QBITTORRENT_WEBUI_HOST:$QBITTORRENT_WEBUI_PORT"
gluetun_base_url="http://$GLUETUN_CONTROL_HOST:$GLUETUN_CONTROL_PORT"

current_port="0"
new_port=$current_port

error_count=0

echo "Waiting $INITIAL_DELAY_SEC seconds for initial delay"
sleep $INITIAL_DELAY_SEC &
wait $!

while :
do
    if [ $error_count -ge $ERROR_INTERVAL_COUNT ]; then
        echo "Reached maximum error count ($error_count), sleeping for $CHECK_INTERVAL_SEC sec"
        sleep $CHECK_INTERVAL_SEC &
        wait $!
        error_count=0
    fi

    echo "Checking port..."
    new_port=$(curl $gluetun_base_url/v1/openvpn/portforwarded 2> /dev/null | jq .port)
    echo "Received: $new_port"

    if [ -z "$new_port" ] || [ "$new_port" = "0" ]; then
        echo "Error: New port is empty or 0"
        error_count=$((error_count+1))
        sleep $ERROR_INTERVAL_SEC &
        wait $!
        continue
    fi

    if [ "$new_port" = "$current_port" ]; then
        echo "New port is the same as current port, nothing to do"
        sleep $CHECK_INTERVAL_SEC &
        wait $!
        continue
    fi

    echo "Updating port..."

    echo "Logging into qBittorrent WebUI"
    login_data="username=$QBITTORRENT_WEBUI_USERNAME&password=$QBITTORRENT_WEBUI_PASSWORD"
    login_url="$qbittorrent_base_url/api/v2/auth/login"
    find_cookie="/set-cookie/ {print substr(\$2, 1, length(\$2)-1)}"
    cookie=$(curl -i --data "$login_data" $login_url 2> /dev/null | awk -e "$find_cookie")

    if [ -z "$cookie" ]; then
        echo "Failed to login to qBittorrent WebUI at $login_url"
        error_count=$((error_count+1))
        sleep $ERROR_INTERVAL_SEC &
        wait $!
        continue
    fi

    echo "Sending new port to qBittorrent WebUI"
    set_preferences_url="$qbittorrent_base_url/api/v2/app/setPreferences"
    curl $set_preferences_url --cookie "$cookie" -d "json={\"listen_port\":$new_port}" 2> /dev/null

    echo "Confirming new port"
    get_preferences_url="$qbittorrent_base_url/api/v2/app/preferences"
    confirm_port=$(curl $get_preferences_url --cookie "$cookie" 2> /dev/null | jq .listen_port)

    echo "Logging out"
    curl -X POST $qbittorrent_base_url/api/v2/auth/logout --cookie "$cookie" 2> /dev/null

    if [ "$confirm_port" != "$new_port" ]; then
        echo "Failed updating port"
        error_count=$((error_count+1))
        sleep $ERROR_INTERVAL_SEC &
        wait $!
        continue
    fi

    echo "Successfully updated port"

    current_port=$new_port

    sleep $CHECK_INTERVAL_SEC &
    wait $!
done

