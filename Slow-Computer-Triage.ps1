# Slow-Computer-Triage.ps1
# Purpose: Diagnose slow computer issues and generate ticket-ready summary

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# ======================
# CONFIG
# ======================
$MaxHops = 3
$TraceWaitMs = 500
$TraceTarget = "google.com"
$PingTarget = "8.8.8.8"
$DNSTarget = "google.com"

# Save log in same folder as script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = "$ScriptDir\slow_computer_triage_log.txt"

# ======================
# START REPORT
# ======================
"===== Slow Computer Triage Report =====" | Out-File $LogFile
"Date: $(Get-Date)" | Out-File $LogFile -Append
"Computer: $env:COMPUTERNAME" | Out-File $LogFile -Append
"User: $env:USERNAME" | Out-File $LogFile -Append
"" | Out-File $LogFile -Append

Write-Host "[1/5] Checking system information and performance..."

# ======================
# SYSTEM CHECKS
# ======================
$OS = Get-CimInstance Win32_OperatingSystem
$Computer = Get-CimInstance Win32_ComputerSystem
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$LastBoot = $OS.LastBootUpTime
$UptimeDays = [math]::Round(((Get-Date) - $LastBoot).TotalDays, 2)

$FreeSpacePercent = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 2)
$UsedRAMPercent = [math]::Round((($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory) / $OS.TotalVisibleMemorySize) * 100, 2)
$CPUUsage = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue, 2)

Write-Host "[2/5] Collecting top CPU and memory processes..."

$TopCPUProcesses = Get-Process |
    Sort-Object CPU -Descending |
    Select-Object -First 5 Name, Id, CPU

$TopMemoryProcesses = Get-Process |
    Sort-Object WorkingSet -Descending |
    Select-Object -First 5 Name, Id, @{Name="Memory_MB";Expression={[math]::Round($_.WorkingSet / 1MB, 2)}}

# ======================
# SMART MODE
# ======================
if ($CPUUsage -ge 80 -or $UsedRAMPercent -ge 85) {
    $ParallelMode = $false
} else {
    $ParallelMode = $true
}

Write-Host "[3/5] Checking network connectivity and DNS..."

if ($ParallelMode) {
    Write-Host "Running network checks in parallel..."

    $jobs = @()

    $jobs += Start-Job -Name "Ping" -ScriptBlock {
        param($Target)
        Test-Connection $Target -Count 2 -Quiet
    } -ArgumentList $PingTarget

    $jobs += Start-Job -Name "DNS" -ScriptBlock {
        param($Target)
        try {
            Resolve-DnsName $Target -ErrorAction Stop | Out-Null
            $true
        } catch {
            $false
        }
    } -ArgumentList $DNSTarget

    Wait-Job $jobs | Out-Null

    $PingPassed = Receive-Job -Name "Ping"
    $DNSPassed = Receive-Job -Name "DNS"

    Remove-Job $jobs
} else {
    Write-Host "Running network checks in low-impact mode..."

    $PingPassed = Test-Connection $PingTarget -Count 2 -Quiet

    try {
        Resolve-DnsName $DNSTarget -ErrorAction Stop | Out-Null
        $DNSPassed = $true
    } catch {
        $DNSPassed = $false
    }
}

# ======================
# RAW NETWORK DATA
# ======================
Write-Host "[4/5] Collecting raw network results and tracing route..."

$PingRaw = Test-Connection $PingTarget -Count 4

try {
    $DNSRaw = Resolve-DnsName $DNSTarget -ErrorAction Stop
} catch {
    $DNSRaw = "DNS lookup failed: $($_.Exception.Message)"
}

Write-Host "Tracing route to $TraceTarget with max $MaxHops hops... please wait."

$TraceJob = Start-Job -ScriptBlock {
    param($Target, $Hops, $Wait)
    tracert -h $Hops -w $Wait $Target
} -ArgumentList $TraceTarget, $MaxHops, $TraceWaitMs

Write-Host "Tracing hops " -NoNewline

while ($TraceJob.State -eq "Running") {
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 300
    $TraceJob = Get-Job -Id $TraceJob.Id
}

Write-Host " done."

$TraceOutput = Receive-Job $TraceJob
Remove-Job $TraceJob

# ======================
# SUMMARY SECTION
# ======================
Write-Host "[5/5] Generating report..."

"===== Summary =====" | Out-File $LogFile -Append
"Uptime Days: $UptimeDays" | Out-File $LogFile -Append
"CPU Usage: $CPUUsage%" | Out-File $LogFile -Append
"Memory Usage: $UsedRAMPercent%" | Out-File $LogFile -Append
"Disk Free: $FreeSpacePercent%" | Out-File $LogFile -Append

if ($PingPassed) {
    "Network: OK" | Out-File $LogFile -Append
} else {
    "Network: FAILED" | Out-File $LogFile -Append
}

if ($DNSPassed) {
    "DNS: OK" | Out-File $LogFile -Append
} else {
    "DNS: FAILED" | Out-File $LogFile -Append
}

"" | Out-File $LogFile -Append

"===== Recommendations =====" | Out-File $LogFile -Append

$RecommendationMade = $false

if ($UptimeDays -ge 3) {
    "- Restart device and retest performance." | Out-File $LogFile -Append
    $RecommendationMade = $true
}

if ($CPUUsage -ge 80) {
    "- Investigate high CPU usage." | Out-File $LogFile -Append
    $RecommendationMade = $true
}

if ($UsedRAMPercent -ge 80) {
    "- Investigate high memory usage." | Out-File $LogFile -Append
    $RecommendationMade = $true
}

if ($FreeSpacePercent -lt 15) {
    "- Free disk space or check for large files." | Out-File $LogFile -Append
    $RecommendationMade = $true
}

if (-not $PingPassed) {
    "- Check network connection, VPN, adapter, or firewall." | Out-File $LogFile -Append
    $RecommendationMade = $true
}

if (-not $DNSPassed) {
    "- Flush DNS and verify DNS/VPN settings." | Out-File $LogFile -Append
    $RecommendationMade = $true
}

if (-not $RecommendationMade) {
    "- No major system, disk, or network issue detected. Continue troubleshooting application-specific causes." | Out-File $LogFile -Append
}

"" | Out-File $LogFile -Append

# ======================
# AUTO TICKET SUMMARY
# ======================
"===== Auto Ticket Summary =====" | Out-File $LogFile -Append
"Issue: Slow computer reported." | Out-File $LogFile -Append
"Device: $env:COMPUTERNAME" | Out-File $LogFile -Append
"User: $env:USERNAME" | Out-File $LogFile -Append
"" | Out-File $LogFile -Append

"Findings:" | Out-File $LogFile -Append

$FindingMade = $false

if ($UptimeDays -ge 7) {
    "- High uptime detected: $UptimeDays days." | Out-File $LogFile -Append
    $FindingMade = $true
}

if ($CPUUsage -ge 80) {
    "- High CPU usage detected: $CPUUsage%." | Out-File $LogFile -Append
    $FindingMade = $true
}

if ($UsedRAMPercent -ge 80) {
    "- Likely Root Cause: High memory usage detected at $UsedRAMPercent%." | Out-File $LogFile -Append
    $FindingMade = $true
}

if ($FreeSpacePercent -lt 15) {
    "- Low disk space detected: $FreeSpacePercent% free." | Out-File $LogFile -Append
    $FindingMade = $true
}

if (-not $PingPassed) {
    "- Network connectivity test failed." | Out-File $LogFile -Append
    $FindingMade = $true
}

if (-not $DNSPassed) {
    "- DNS resolution test failed." | Out-File $LogFile -Append
    $FindingMade = $true
}

if (-not $FindingMade) {
    "- No major system, disk, or network issue detected during initial triage." | Out-File $LogFile -Append
}

"" | Out-File $LogFile -Append
"Actions Taken:" | Out-File $LogFile -Append
"- Ran automated slow-computer triage script." | Out-File $LogFile -Append
"- Reviewed uptime, CPU, memory, disk space, top processes, IP configuration, connectivity, DNS, and traceroute." | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"Next Steps:" | Out-File $LogFile -Append

if ($UptimeDays -ge 7) {
    "- Restart system and retest performance." | Out-File $LogFile -Append
}

if ($CPUUsage -ge 80 -or $UsedRAMPercent -ge 80) {
    "- Review top resource-consuming processes and close/restart unnecessary applications." | Out-File $LogFile -Append
}

if (-not $PingPassed) {
    "- Verify network connection, VPN status, and network adapter configuration." | Out-File $LogFile -Append
}

if (-not $DNSPassed) {
    "- Flush DNS and verify DNS/VPN settings." | Out-File $LogFile -Append
}

if (-not $RecommendationMade) {
    "- Continue troubleshooting app-specific slowness, browser issues, user profile issues, or endpoint policy issues." | Out-File $LogFile -Append
}

"" | Out-File $LogFile -Append

# ======================
# DETAILED RAW RESULTS
# ======================
"===== Detailed Raw Results =====" | Out-File $LogFile -Append

"--- System Information ---" | Out-File $LogFile -Append
"OS: $($OS.Caption)" | Out-File $LogFile -Append
"OS Version: $($OS.Version)" | Out-File $LogFile -Append
"Manufacturer: $($Computer.Manufacturer)" | Out-File $LogFile -Append
"Model: $($Computer.Model)" | Out-File $LogFile -Append
"RAM: $([math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)) GB" | Out-File $LogFile -Append
"Last Boot Time: $LastBoot" | Out-File $LogFile -Append
"" | Out-File $LogFile -Append

"--- Top 5 Processes by CPU Usage ---" | Out-File $LogFile -Append
$TopCPUProcesses |
    Format-Table -AutoSize |
    Out-File $LogFile -Append

"--- Top 5 Processes by Memory Usage ---" | Out-File $LogFile -Append
$TopMemoryProcesses |
    Format-Table -AutoSize |
    Out-File $LogFile -Append

"--- IP Configuration ---" | Out-File $LogFile -Append
ipconfig /all | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"--- Ping Test: $PingTarget ---" | Out-File $LogFile -Append
$PingRaw | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"--- DNS Resolution Test: $DNSTarget ---" | Out-File $LogFile -Append
$DNSRaw | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"--- Traceroute: $TraceTarget, $MaxHops hops max ---" | Out-File $LogFile -Append
$TraceOutput | Out-File $LogFile -Append

"" | Out-File $LogFile -Append
"===== End of Report =====" | Out-File $LogFile -Append

Write-Host ""
Write-Host "Triage complete."
Write-Host "Report saved to: $LogFile"