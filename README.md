# Network Statistics Collection Script

A comprehensive bash script for macOS that collects detailed network, system, and performance statistics at regular intervals and stores them in both CSV format and Google Sheets.

## Features

### Network Metrics
- **WiFi Status**: Connection state (Connected/Disconnected)
- **SSID**: Network name
- **Wireless Signal**: Signal strength in dBm
- **Wireless Channel**: WiFi channel number
- **Local IP**: Local network IP address (en0)
- **Egress IP**: Public/external IP address
- **DNS Server**: Primary DNS server IP
- **DNS Latency**: Ping time to DNS server (falls back to 8.8.8.8 if unavailable)

### VPN Metrics
- **VPN Connected**: Yes/No status
- **VPN Name**: Name of connected VPN (e.g., "NordVPN NordLynx")
- **VPN Tunnel IP**: Internal VPN IP address
- **VPN Latency**: Ping time to VPN gateway

### System Metrics
- **Hostname**: Computer hostname
- **MacBook Model**: Full model name including chip (e.g., "MacBook Pro M2 Pro")
- **Citrix Version**: Citrix Workspace client version (if installed)
- **Last Sleep Time**: Date/time when Mac last went to sleep
- **Last Lid Close Time**: Date/time when MacBook lid was last closed (uses "Clamshell Sleep" events)
- **Memory Free**: Available memory in MB (includes free, inactive, and speculative pages)
- **CPU Usage**: CPU usage percentage

### Latency Tests
- **Google DNS**: Latency to 8.8.8.8
- **US East Coast**: Latency to AWS US-East (Virginia) - 54.221.192.0
- **US West Coast**: Latency to OpenDNS (San Francisco) - 208.67.222.222

### Speed Tests
- **Download Speed**: Measured in Mbps using 10MB test file
- **Upload Speed**: Measured in Mbps using 2MB test file

## Requirements

### macOS Built-in Tools
The script uses standard macOS utilities:
- `networksetup`
- `system_profiler`
- `ifconfig`
- `scutil`
- `netstat`
- `ping`
- `curl`
- `vm_stat`
- `top`

### Additional Dependencies
- **jq**: JSON processor for Google Sheets integration
  ```bash
  brew install jq
  ```

- **bc**: Basic calculator for mathematical operations (usually pre-installed)

## Installation

1. Clone or download the script:
   ```bash
   cd ~/github/bash
   chmod +x network_stats.sh
   ```

2. Install jq if not already installed:
   ```bash
   brew install jq
   ```

## Configuration

### Google Sheets Integration

The script is configured to send data to Google Sheets. To set up:

1. **Create a Google Sheet** for your data

2. **Set up Google Apps Script**:
   - Go to **Extensions > Apps Script**
   - Replace the code with:
     ```javascript
     function doPost(e) {
       try {
         var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
         var data = JSON.parse(e.postData.contents);

         // If this is the first row, add headers
         if (sheet.getLastRow() === 0) {
           sheet.appendRow(data.headers);
         }

         // Append the data row
         sheet.appendRow(data.values);

         return ContentService.createTextOutput(JSON.stringify({status: 'success'}))
           .setMimeType(ContentService.MimeType.JSON);
       } catch(error) {
         return ContentService.createTextOutput(JSON.stringify({status: 'error', message: error.toString()}))
           .setMimeType(ContentService.MimeType.JSON);
       }
     }
     ```

3. **Deploy the script**:
   - Click **Deploy > New deployment**
   - Select type: **Web app**
   - Set "Execute as": **Me**
   - Set "Who has access": **Anyone**
   - Click **Deploy** and copy the Web App URL

4. **Update the script**:
   - Edit `network_stats.sh`
   - Replace the `GOOGLE_SHEETS_URL` variable with your Web App URL

### Disable Google Sheets

To disable Google Sheets integration and only use CSV:

1. Comment out or remove the Google Sheets URL:
   ```bash
   # GOOGLE_SHEETS_URL=""
   ```

2. Comment out the Google Sheets POST requests (lines that contain `curl` to `GOOGLE_SHEETS_URL`)

## Usage

### Basic Usage

Run the script:
```bash
./network_stats.sh
```

The script will:
- Create a timestamped CSV file (e.g., `network_stats_20251023_143022.csv`)
- Send data to Google Sheets (if configured)
- Display a green link to view your Google Sheets data in real-time
- Display real-time statistics in the console
- Collect data every 15 seconds

### Stop the Script

Press `Ctrl+C` to stop collection

## Data Collection Interval

- **Main metrics**: Collected every 15 seconds
- **Speed tests**: Run every 15 seconds (configurable)

To change the interval, modify the `sleep 15` line at the end of the main loop.

## Output Format

### CSV File
Data is saved to a timestamped CSV file with the following columns:

```
Timestamp,Hostname,MacBook_Model,Citrix_Version,Last_Sleep_Time,Last_Lid_Close_Time,
WiFi_Status,SSID,Wireless_Signal,Wireless_Channel,Local_IP,Egress_IP,VPN_Tunnel_IP,
DNS_Server,DNS_Latency_ms,VPN_Connected,VPN_Name,VPN_Latency_ms,Memory_Free_MB,
CPU_Usage_Percent,Latency_Google_ms,Latency_US_East_Coast_ms,Latency_US_West_Coast_ms,
Download_Mbps,Upload_Mbps
```

### Console Output
Real-time display showing:
```
[2025-10-23 14:30:15] hostname (MacBook Pro M2 Pro) Citrix:25.03.10 |
WiFi: Connected | SSID: NetworkName | Signal: -65 dBm | Channel: 36 |
Local IP: 192.168.1.100 | Egress IP: 65.31.177.28 | VPN Tunnel: 10.5.0.2 |
DNS: 192.168.1.1 (2.5ms) | VPN: Yes (15.7ms) - NordVPN NordLynx |
Mem Free: 8192.50MB | CPU: 12.5% | Latency: Google=18.7 ms, US-East=45.2 ms,
US-West=17.4 ms | Down: 85.32 Mbps | Up: 22.45 Mbps
```

**Note**: Last Sleep Time and Last Lid Close Time are tracked but not displayed in console output (available in CSV and Google Sheets).

## Speed Test Details

### Download Test
- Uses a 10MB test file from `https://proof.ovh.net/files/10Mb.dat`
- Timeout: 15 seconds
- Calculates speed based on file size and download duration

### Upload Test
- Creates a 2MB test file locally
- Uploads to `http://httpbin.org/post`
- Timeout: 30 seconds
- Calculates speed based on file size and upload duration

## Troubleshooting

### Common Issues

**Script shows N/A for many values**
- Check your internet connection
- Ensure WiFi is enabled
- Verify you have permissions to run network commands

**Speed tests timing out**
- Your connection might be slow
- Increase timeout values in the script
- Check firewall settings

**Google Sheets not updating**
- Verify the Web App URL is correct
- Check that the Google Apps Script is deployed
- Ensure "Who has access" is set to "Anyone"
- Check internet connectivity

**jq command not found**
- Install jq: `brew install jq`

**VPN metrics showing N/A when connected**
- Your VPN might not be compatible with `scutil --nc list`
- Check `scutil --nc list` manually to verify VPN detection

### Permissions

The script requires:
- Network access for speed tests
- Access to system profiler
- Ability to read network configuration

No special sudo permissions are required.

## Customization

### Change Collection Interval
Edit the `sleep` value in the main loop (currently line ~396):
```bash
sleep 15  # Change to desired seconds
```

### Modify Latency Test Targets
Edit the latency test section (around line ~360):
```bash
latency_google=$(get_latency "8.8.8.8")
latency_us_east=$(get_latency "YOUR_IP_HERE")
latency_us_west=$(get_latency "YOUR_IP_HERE")
```

### Change Speed Test Files
Edit the `run_speedtest()` function:
- Download URL: line ~272
- Upload size: line ~297 (`count=2` for 2MB)

## File Locations

- **Script**: `/Users/duanehaas/github/bash/network_stats.sh`
- **CSV Output**: Same directory as script
- **Temp Files**: `/tmp/speedtest_*.tmp` (automatically cleaned up)

## Performance Impact

- **CPU Usage**: Minimal (~1-2% on average)
- **Network Usage**: ~12MB per iteration (10MB download + 2MB upload)
- **Disk Usage**: CSV file grows by ~250 bytes per row
- **Google Sheets**: One API call per iteration (15 seconds)

## Security Considerations

- **Egress IP**: Your public IP is collected and stored
- **Local IP**: Your private network IP is collected
- **VPN Details**: VPN configuration is exposed in the data
- **Google Sheets**: Data is sent to a publicly accessible webhook (if configured)

**Recommendation**: Keep CSV files and Google Sheets private

## License

This script is provided as-is for personal and educational use.

## Author

Created for network monitoring and diagnostics on macOS.

## Version History

- **v1.3** - Improved lid close detection and user experience enhancements
  - Updated lid close tracking to use "Clamshell Sleep" events for more accurate detection
  - Added green-colored Google Sheets link display on script startup for easy access
- **v1.2** - Added Last Sleep Time and Last Lid Close Time tracking via pmset logs
- **v1.1** - Added Google Sheets integration, VPN name and tunnel IP tracking
- **v1.0** - Initial release with comprehensive network, VPN, and system metrics
  - Native speed test implementation
  - Citrix Workspace version detection
  - Multi-location latency testing
