#!/bin/bash

# Network Statistics Collection Script
# Collects WiFi status, latency, and speed test data every 15 seconds

CSV_FILE="network_stats_$(date +%Y%m%d_%H%M%S).csv"
GOOGLE_SHEETS_URL="https://script.google.com/macros/s/AKfycbw1_KUy9wbTo-3iVUEVgQQt-S7IBGMBORmDY9J2p0Wm7Dx6Etl5mFkHT_9dWgPLFFYO/exec"

# Headers array
HEADERS=("Timestamp" "Hostname" "MacBook_Model" "Citrix_Version" "Last_Sleep_Time" "Last_Lid_Close_Time" "WiFi_Status" "SSID" "Wireless_Signal" "Wireless_Channel" "Local_IP" "Egress_IP" "VPN_Tunnel_IP" "DNS_Server" "DNS_Latency_ms" "VPN_Connected" "VPN_Name" "VPN_Latency_ms" "Memory_Free_MB" "CPU_Usage_Percent" "Latency_Google_ms" "Latency_US_East_Coast_ms" "Latency_US_West_Coast_ms" "Download_Mbps" "Upload_Mbps")

# Create CSV header
echo "Timestamp,Hostname,MacBook_Model,Citrix_Version,Last_Sleep_Time,Last_Lid_Close_Time,WiFi_Status,SSID,Wireless_Signal,Wireless_Channel,Local_IP,Egress_IP,VPN_Tunnel_IP,DNS_Server,DNS_Latency_ms,VPN_Connected,VPN_Name,VPN_Latency_ms,Memory_Free_MB,CPU_Usage_Percent,Latency_Google_ms,Latency_US_East_Coast_ms,Latency_US_West_Coast_ms,Download_Mbps,Upload_Mbps" > "$CSV_FILE"

# Send headers to Google Sheets
HEADERS_JSON=$(printf '%s\n' "${HEADERS[@]}" | jq -R . | jq -s .)
curl -s -L -X POST "$GOOGLE_SHEETS_URL" \
  -H "Content-Type: application/json" \
  -d "{\"headers\": $HEADERS_JSON, \"values\": []}" > /dev/null

echo "Starting network statistics collection..."
echo "Data will be saved to: $CSV_FILE"
echo "Data will also be sent to Google Sheets"
echo "Press Ctrl+C to stop"
echo ""

# Function to get hostname
get_hostname() {
    local hostname=$(hostname -s)
    echo "$hostname"
}

# Function to get MacBook model
get_macbook_model() {
    local model=$(system_profiler SPHardwareDataType | grep "Model Name:" | awk -F': ' '{print $2}')
    local chip=$(system_profiler SPHardwareDataType | grep "Chip:" | awk -F': ' '{print $2}' | sed 's/Apple //')

    if [ -z "$model" ]; then
        echo "N/A"
    elif [ -n "$chip" ]; then
        echo "$model $chip"
    else
        # Fallback for Intel Macs
        local processor=$(system_profiler SPHardwareDataType | grep "Processor Name:" | awk -F': ' '{print $2}')
        if [ -n "$processor" ]; then
            echo "$model $processor"
        else
            echo "$model"
        fi
    fi
}

# Function to get Citrix Workspace version
get_citrix_version() {
    local version=$(defaults read /Applications/Citrix\ Workspace.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)
    if [ -z "$version" ]; then
        echo "N/A"
    else
        echo "$version"
    fi
}

# Function to get last sleep time
get_last_sleep_time() {
    local sleep_time=$(pmset -g log | grep -E "Sleep.*due to" | tail -1 | awk '{print $1" "$2}')
    if [ -z "$sleep_time" ]; then
        echo "N/A"
    else
        echo "$sleep_time"
    fi
}

# Function to get last lid close time
get_last_lid_close_time() {
    local lid_close_time=$(pmset -g log | grep -E "Display is turned off" | tail -1 | awk '{print $1" "$2}')
    if [ -z "$lid_close_time" ]; then
        echo "N/A"
    else
        echo "$lid_close_time"
    fi
}

# Function to get WiFi status
get_wifi_status() {
    local status=$(networksetup -getairportpower en0 | awk '{print $4}')
    if [ "$status" == "On" ]; then
        echo "Connected"
    else
        echo "Disconnected"
    fi
}

# Function to get SSID
get_ssid() {
    local ssid=$(system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/ {getline; gsub(/:$/,"",$1); print $1; exit}')
    if [ -z "$ssid" ]; then
        echo "N/A"
    else
        echo "$ssid"
    fi
}

# Function to get signal strength
get_signal_strength() {
    local signal=$(system_profiler SPAirPortDataType 2>/dev/null | grep "Signal / Noise:" | head -1 | awk '{print $4}')
    if [ -z "$signal" ]; then
        echo "N/A"
    else
        echo "$signal"
    fi
}

# Function to get wireless channel
get_wireless_channel() {
    local channel=$(system_profiler SPAirPortDataType 2>/dev/null | grep "Channel:" | head -1 | awk '{print $2}')
    if [ -z "$channel" ]; then
        echo "N/A"
    else
        echo "$channel"
    fi
}

# Function to get local IP
get_local_ip() {
    local ip=$(ifconfig en0 | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    if [ -z "$ip" ]; then
        echo "N/A"
    else
        echo "$ip"
    fi
}

# Function to get free memory in MB
get_memory_free() {
    # Get page size (typically 16384 on Apple Silicon, 4096 on Intel)
    local page_size=$(vm_stat | head -1 | grep -o '[0-9]*')

    # Get free, inactive, and speculative pages for available memory
    local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local inactive_pages=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    local speculative_pages=$(vm_stat | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')

    # Calculate total available memory
    local total_available_pages=$((free_pages + inactive_pages + speculative_pages))
    local available_bytes=$((total_available_pages * page_size))
    local available_mb=$(echo "scale=2; $available_bytes / 1048576" | bc)
    echo "$available_mb"
}

# Function to get CPU usage percentage
get_cpu_usage() {
    local cpu_usage=$(top -l 2 -n 0 -s 1 | grep "CPU usage" | tail -1 | awk '{print $3}' | sed 's/%//')
    if [ -z "$cpu_usage" ]; then
        echo "N/A"
    else
        echo "$cpu_usage"
    fi
}

# Function to get egress IP
get_egress_ip() {
    local ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
    if [ -z "$ip" ]; then
        echo "N/A"
    else
        echo "$ip"
    fi
}

# Function to get VPN tunnel IP
get_vpn_tunnel_ip() {
    # Check if VPN is connected
    local vpn_connected=$(scutil --nc list 2>/dev/null | grep "(Connected)")
    if [ -z "$vpn_connected" ]; then
        echo "N/A"
        return
    fi

    # Find the active VPN interface (utun with highest number is usually the active VPN)
    local vpn_interface=$(netstat -nr | grep "default" | grep -E "utun[3-9]|utun[0-9][0-9]|ppp|ipsec|tun|tap" | head -1 | awk '{print $NF}')
    if [ -z "$vpn_interface" ]; then
        echo "N/A"
        return
    fi

    # Get the VPN tunnel IP address
    local tunnel_ip=$(ifconfig "$vpn_interface" 2>/dev/null | grep "inet " | awk '{print $2}')
    if [ -z "$tunnel_ip" ]; then
        echo "N/A"
    else
        echo "$tunnel_ip"
    fi
}

# Function to get DNS server
get_dns_server() {
    local dns=$(scutil --dns | grep "nameserver\[0\]" | head -1 | awk '{print $3}')
    if [ -z "$dns" ]; then
        echo "N/A"
    else
        echo "$dns"
    fi
}

# Function to get DNS server latency
get_dns_latency() {
    local dns=$(scutil --dns | grep "nameserver\[0\]" | head -1 | awk '{print $3}')

    # If no DNS server found, use Google DNS as fallback
    if [ -z "$dns" ]; then
        dns="8.8.8.8"
    fi

    local latency=$(ping -c 1 -W 1000 "$dns" 2>/dev/null | awk -F'/' 'END{print $5}')

    # If ping to DNS server failed, fall back to Google DNS
    if [ -z "$latency" ]; then
        latency=$(ping -c 1 -W 1000 "8.8.8.8" 2>/dev/null | awk -F'/' 'END{print $5}')
        if [ -z "$latency" ]; then
            echo "N/A"
        else
            echo "$latency"
        fi
    else
        echo "$latency"
    fi
}

# Function to check if VPN is connected
get_vpn_status() {
    # Check scutil for active VPN connections
    local scutil_vpn=$(scutil --nc list 2>/dev/null | grep "(Connected)")
    if [ -z "$scutil_vpn" ]; then
        echo "No"
    else
        echo "Yes"
    fi
}

# Function to get VPN name
get_vpn_name() {
    # Check scutil for active VPN connections and extract the name
    local vpn_name=$(scutil --nc list 2>/dev/null | grep "(Connected)" | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$vpn_name" ]; then
        echo "N/A"
    else
        echo "$vpn_name"
    fi
}

# Function to get VPN gateway IP and latency
get_vpn_latency() {
    # Check if VPN is connected
    local vpn_connected=$(scutil --nc list 2>/dev/null | grep "(Connected)")
    if [ -z "$vpn_connected" ]; then
        echo "N/A"
        return
    fi

    # Find the VPN interface (utun with highest number is usually the active VPN)
    local vpn_interface=$(netstat -nr | grep "default" | grep -E "utun[3-9]|utun[0-9][0-9]|ppp|ipsec|tun|tap" | head -1 | awk '{print $NF}')
    if [ -z "$vpn_interface" ]; then
        echo "N/A"
        return
    fi

    # Get the local VPN IP and try to derive gateway (usually .1 or the peer IP)
    local vpn_ip=$(ifconfig "$vpn_interface" 2>/dev/null | grep "inet " | awk '{print $2}')
    if [ -z "$vpn_ip" ]; then
        echo "N/A"
        return
    fi

    # Try common gateway patterns: x.x.x.1 or the peer IP from point-to-point
    local vpn_gateway=""

    # First try the peer IP (for point-to-point interfaces)
    local peer_ip=$(ifconfig "$vpn_interface" 2>/dev/null | grep "inet " | awk '{print $4}')
    if [ -n "$peer_ip" ] && [ "$peer_ip" != "$vpn_ip" ]; then
        vpn_gateway="$peer_ip"
    else
        # Try .1 of the subnet
        vpn_gateway=$(echo "$vpn_ip" | awk -F'.' '{print $1"."$2"."$3".1"}')
    fi

    # Measure latency to VPN gateway
    local latency=$(ping -c 1 -W 1000 "$vpn_gateway" 2>/dev/null | awk -F'/' 'END{print $5}')
    if [ -z "$latency" ]; then
        echo "N/A"
    else
        echo "$latency"
    fi
}

# Function to measure latency to a specific IP
get_latency() {
    local target=$1
    local latency=$(ping -c 1 -W 1000 "$target" 2>/dev/null | awk -F'/' 'END{print $5}')
    if [ -z "$latency" ]; then
        echo "N/A"
    else
        echo "$latency"
    fi
}

# Function to run speed test (native implementation)
run_speedtest() {
    # Download speed test using a 10MB file from a reliable CDN
    local test_url="https://proof.ovh.net/files/10Mb.dat"
    local test_file="/tmp/speedtest_$$.tmp"

    # Measure download speed
    local start_time=$(date +%s.%N)
    curl -s -o "$test_file" --max-time 15 "$test_url" 2>/dev/null
    local curl_exit=$?
    local end_time=$(date +%s.%N)

    if [ $curl_exit -ne 0 ] || [ ! -f "$test_file" ]; then
        rm -f "$test_file" 2>/dev/null
        echo "N/A,N/A"
        return
    fi

    # Calculate download speed in Mbps
    local file_size=$(stat -f%z "$test_file" 2>/dev/null || echo "0")
    local duration=$(echo "$end_time - $start_time" | bc)

    rm -f "$test_file"

    if [ -z "$duration" ] || [ "$file_size" = "0" ]; then
        echo "N/A,N/A"
        return
    fi

    # Convert bytes/second to Mbps: (bytes * 8) / (duration * 1000000)
    local download_mbps=$(echo "scale=2; ($file_size * 8) / ($duration * 1000000)" | bc)

    # Upload speed test - create a 2MB test file and upload it
    local upload_file="/tmp/speedtest_upload_$$.tmp"
    dd if=/dev/zero of="$upload_file" bs=1048576 count=2 2>/dev/null

    local upload_size=$(stat -f%z "$upload_file" 2>/dev/null || echo "0")

    local upload_start=$(date +%s.%N)
    curl -s -X POST -F "file=@$upload_file" --max-time 30 "http://httpbin.org/post" -o /dev/null 2>/dev/null
    local upload_exit=$?
    local upload_end=$(date +%s.%N)

    rm -f "$upload_file"

    if [ $upload_exit -ne 0 ] || [ "$upload_size" = "0" ]; then
        echo "$download_mbps,N/A"
        return
    fi

    local upload_duration=$(echo "$upload_end - $upload_start" | bc)

    if [ -z "$upload_duration" ]; then
        echo "$download_mbps,N/A"
        return
    fi

    # Convert bytes/second to Mbps
    local upload_mbps=$(echo "scale=2; ($upload_size * 8) / ($upload_duration * 1000000)" | bc)

    echo "$download_mbps,$upload_mbps"
}

# Main collection loop
iteration=0
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    hostname=$(get_hostname)
    macbook_model=$(get_macbook_model)
    citrix_version=$(get_citrix_version)
    last_sleep_time=$(get_last_sleep_time)
    last_lid_close_time=$(get_last_lid_close_time)
    wifi_status=$(get_wifi_status)
    ssid=$(get_ssid)
    signal=$(get_signal_strength)
    wireless_channel=$(get_wireless_channel)
    local_ip=$(get_local_ip)
    egress_ip=$(get_egress_ip)
    vpn_tunnel_ip=$(get_vpn_tunnel_ip)
    dns_server=$(get_dns_server)
    dns_latency=$(get_dns_latency)
    vpn_status=$(get_vpn_status)
    vpn_name=$(get_vpn_name)
    vpn_latency=$(get_vpn_latency)
    memory_free=$(get_memory_free)
    cpu_usage=$(get_cpu_usage)

    # Test latency to multiple locations
    latency_google=$(get_latency "8.8.8.8")                    # Google DNS
    latency_us_east=$(get_latency "54.221.192.0")              # AWS US-East Coast (Virginia)
    latency_us_west=$(get_latency "208.67.222.222")            # OpenDNS US-West Coast (San Francisco)

    # Run speed test every iteration
    speeds=$(run_speedtest)

    # Parse download and upload speeds
    download=$(echo "$speeds" | cut -d',' -f1)
    upload=$(echo "$speeds" | cut -d',' -f2)

    # Write data to CSV
    echo "$timestamp,$hostname,$macbook_model,$citrix_version,$last_sleep_time,$last_lid_close_time,$wifi_status,$ssid,$signal,$wireless_channel,$local_ip,$egress_ip,$vpn_tunnel_ip,$dns_server,$dns_latency,$vpn_status,$vpn_name,$vpn_latency,$memory_free,$cpu_usage,$latency_google,$latency_us_east,$latency_us_west,$download,$upload" >> "$CSV_FILE"

    # Send data to Google Sheets
    DATA_JSON=$(jq -n \
      --arg timestamp "$timestamp" \
      --arg hostname "$hostname" \
      --arg macbook_model "$macbook_model" \
      --arg citrix_version "$citrix_version" \
      --arg last_sleep_time "$last_sleep_time" \
      --arg last_lid_close_time "$last_lid_close_time" \
      --arg wifi_status "$wifi_status" \
      --arg ssid "$ssid" \
      --arg signal "$signal" \
      --arg wireless_channel "$wireless_channel" \
      --arg local_ip "$local_ip" \
      --arg egress_ip "$egress_ip" \
      --arg vpn_tunnel_ip "$vpn_tunnel_ip" \
      --arg dns_server "$dns_server" \
      --arg dns_latency "$dns_latency" \
      --arg vpn_status "$vpn_status" \
      --arg vpn_name "$vpn_name" \
      --arg vpn_latency "$vpn_latency" \
      --arg memory_free "$memory_free" \
      --arg cpu_usage "$cpu_usage" \
      --arg latency_google "$latency_google" \
      --arg latency_us_east "$latency_us_east" \
      --arg latency_us_west "$latency_us_west" \
      --arg download "$download" \
      --arg upload "$upload" \
      '{headers: [], values: [$timestamp, $hostname, $macbook_model, $citrix_version, $last_sleep_time, $last_lid_close_time, $wifi_status, $ssid, $signal, $wireless_channel, $local_ip, $egress_ip, $vpn_tunnel_ip, $dns_server, $dns_latency, $vpn_status, $vpn_name, $vpn_latency, $memory_free, $cpu_usage, $latency_google, $latency_us_east, $latency_us_west, $download, $upload]}')

    curl -s -L -X POST "$GOOGLE_SHEETS_URL" \
      -H "Content-Type: application/json" \
      -d "$DATA_JSON" > /dev/null

    # Display current reading
    if [ "$vpn_latency" = "N/A" ]; then
        vpn_display="$vpn_status"
    else
        vpn_display="$vpn_status (${vpn_latency}ms)"
    fi

    if [ "$vpn_name" != "N/A" ]; then
        vpn_display="$vpn_display - $vpn_name"
    fi

    if [ "$dns_latency" = "N/A" ]; then
        dns_display="$dns_server"
    else
        dns_display="$dns_server (${dns_latency}ms)"
    fi

    echo "[$timestamp] $hostname ($macbook_model) Citrix:$citrix_version | WiFi: $wifi_status | SSID: $ssid | Signal: $signal dBm | Channel: $wireless_channel | Local IP: $local_ip | Egress IP: $egress_ip | VPN Tunnel: $vpn_tunnel_ip | DNS: $dns_display | VPN: $vpn_display | Mem Free: ${memory_free}MB | CPU: ${cpu_usage}% | Latency: Google=$latency_google ms, US-East=$latency_us_east ms, US-West=$latency_us_west ms | Down: $download Mbps | Up: $upload Mbps"

    # Increment iteration counter
    iteration=$((iteration + 1))

    # Wait 15 seconds
    sleep 15
done
