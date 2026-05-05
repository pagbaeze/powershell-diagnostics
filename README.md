# PowerShell Diagnostics Tool

This project automates slow computer troubleshooting using PowerShell. It collects system, performance, and network diagnostics, then generates a report with findings and recommended next steps.

---

## Features

- Checks system uptime
- Reviews CPU, memory, and disk usage
- Lists top CPU and memory-consuming processes
- Tests network connectivity
- Tests DNS resolution
- Runs traceroute analysis
- Generates a ticket-ready summary
- Provides recommended troubleshooting actions

---

## How to Run

### Option 1 (Windows)
Double click:
run_triage.bat

### Option 2 (PowerShell)
Open PowerShell in the project folder and run:

powershell -ExecutionPolicy Bypass -File .\Slow-Computer-Triage.ps1

---

## Output

slow_computer_triage_log.txt

The report includes:
- System information
- Uptime results
- CPU, memory, and disk usage
- Top processes
- IP configuration
- Ping and DNS results
- Traceroute output
- Recommended next steps
- Auto ticket summary

---

## Sample Output

Example diagnostic report:
sample_output/slow_computer_triage_log.txt

This output demonstrates:
- Slow computer triage workflow
- High resource usage detection
- Network and DNS troubleshooting
- Ticket-ready findings and next steps

---

## Purpose

This project demonstrates practical IT automation using PowerShell. It was built to reduce manual troubleshooting steps and standardize slow-computer diagnostics.

## Design Considerations

This script was developed iteratively, starting as a basic diagnostic tool and evolving into a more efficient and user-friendly troubleshooting solution.

### Execution Flow

The script performs system checks (CPU, memory, disk, uptime) sequentially to avoid adding unnecessary load on already slow machines. Network-related checks are handled carefully to balance performance and responsiveness.

### Controlled Parallelization

Certain network-bound operations, such as ping and DNS resolution, can be executed in parallel since they rely on external responses rather than local CPU usage. However, full parallelization was intentionally avoided to prevent overloading systems experiencing performance issues.

### Configurable Traceroute Depth

Traceroute hop count is configurable using a variable (e.g., `$MaxHops`). This allows flexibility depending on the use case:

- Lower hop count (8–12): faster execution for helpdesk scenarios  
- Higher hop count: deeper network path analysis for advanced troubleshooting  

### Usability Improvements

- Added status messages to indicate which test is running  
- Included both summarized findings and raw output for validation  
- Generated a ticket-ready summary to streamline support workflows  

