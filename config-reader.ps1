###

$now = Get-Date "2024-10-14"
$weekAgo = $now.AddDays(-7)



# Function to look for a pattern in the files which lets us find
# the dates of when the files were last modified
function Get-LastDate {
        param (
                [String]$FilePath
        )

        $pattern = '\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2}:\d{2})?'
        $content = Get-Content -Path $FilePath -Raw
        $dateMatches = [Regex]::Matches($content, $pattern)

        $validDates = @()
        foreach ($match in $dateMatches) {
                try {
                        $parsedDate = [DateTime]::Parse($match.Value)
                        $validDates += $parsedDate
                }
                catch {
                        Write-Host "Ogiltigt datum: $($match.Value)"
                }
        }

        if ($validDates.Count -gt 0) {
                $sortedDates = $validDates | Sort-Object -Descending
                return $sortedDates[0].ToString("yyyy-MM-dd")
        }

        return "UNKNOWN"
}

# Collects all .conf, .rules och .log files
$allFiles = Get-ChildItem -Path "network_configs" -Recurse -Include *.conf, *.rules, *.log

# Start of the report
$report = ""


# Creates a list of the files and adds it to the report
$formattedFiles = $allFiles | Select-Object `
@{Name = "File Name"; Expression = { $_.Name } },
@{Name = "Size (KB)"; Expression = { [Math]::Round($_.Length / 1KB, 2) } },
@{Name = "Last Update"; Expression = {
                $lastDate = Get-LastDate -FilePath $_.FullName
                if ($lastDate -eq "UNKNOWN") { "UNKNOWN" } else { $lastDate }
        }
} |
Sort-Object "Last Update" -Descending |
Format-Table -AutoSize | Out-String

$report += @"
===============================
        SYSTEMS ANALYSIS
===============================

FILE OVERVIEW
------------------------------------
"@

$report += $formattedFiles


$recentFiles = $allFiles | Where-Object {
        $lastDate = Get-LastDate -FilePath $_.FullName
        if ($lastDate -eq "UNKNOWN") { return $false }
        $parsedDate = [DateTime]::Parse($lastDate)
        return $parsedDate -ge $weekAgo
}

# Creates list of recently modified files
$recentList = $recentFiles | Select-Object `
@{Name = "File Name"; Expression = { $_.Name } },
@{Name = "Size (KB)"; Expression = { [Math]::Round($_.Length / 1KB, 2) } },
@{Name = "Last Update"; Expression = { Get-LastDate -FilePath $_.FullName } } |
Sort-Object "Last Update" -Descending |
Format-Table -AutoSize | Out-String

$report += @"

RECENTLY MODIFIED FILES (< 7 dagar)
----------------------------------------
"@

$report += $recentList


# Groups files by file extension
$fileGroups = Get-ChildItem -Path "network_configs" -File -Recurse |
Group-Object -Property Extension

# Creates a list showing the number of files and their size in MB and KB
$fileTypeList = $fileGroups | Select-Object `
@{Name = "Extension"; Expression = { $_.Name } },
@{Name = "Amount"; Expression = { $_.Count } },
@{Name = "Size (MB)"; Expression = { '{0:N6}' -f (($_.Group | Measure-Object Length -Sum).Sum / 1MB) } }, 
@{Name = "Size (KB)"; Expression = { [Math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1KB, 2) } } |
Format-Table -AutoSize | Out-String

$report += @"

FILETYPES AND TOTAL SIZE
----------------------------
"@
$report += $fileTypeList


# Finds the .log files
$logFiles = Get-ChildItem -Path "network_configs" -Recurse -Include *.log

$largestLogs = $logFiles | Sort-Object Length -Descending | Select-Object -First 5

# Collect the 5 largest .log files
$largestLogList = $largestLogs | Select-Object `
@{Name = "File Name"; Expression = { $_.Name } }, 
@{Name = "Size (MB)"; Expression = { '{0:N6}' -f ($_.Length / 1MB) } } |
Format-Table -AutoSize | Out-String

$report += @"

LARGEST LOG FILES (TOP 5)
----------------------------
"@

$report += $largestLogList


# Looks for IP address patterns to add to the report
$ipPattern = "\b(?:\d{1,3}\.){3}\d{1,3}\b"
$confFiles = Get-ChildItem -Path "network_configs" -Filter "*.conf" -Recurse

$ipMatches = @()
foreach ($file in $confFiles) {
        $lines = Get-Content -Path $file.FullName
        foreach ($line in $lines) {
                if ($line -match $ipPattern) {
                        $ipMatches += ($line | Select-String -Pattern $ipPattern).Matches.Value
                }
        }
}

# Sorts IPs and removes default route (0.0.0.0) from showing up in the report
$uniqueIPs = $ipMatches | Where-Object { $_ -ne "0.0.0.0" } | Sort-Object -Unique

$report += @"

UNIQUE IP-ADDRESSES
----------------------------

"@


if ($uniqueIPs.Count -gt 0) {
        $report += ($uniqueIPs | ForEach-Object { " - $_" } | Out-String)
}
else {
        $report += "No IP-addresses found in .conf files`n"
}


# Searches for the keywords in the log files
$keywords = @("ERROR", "FAILED", "DENIED")
$logFiles = Get-ChildItem -Path "network_configs" -Filter "*.log" -Recurse

$report += @"

SECURITY ISSUES IN LOG FILES
----------------------------------------

"@

# Makes a list to add to the report
foreach ($log in $logFiles) {
        $report += "File: $($log.Name)`r`n"

        foreach ($keyword in $keywords) {
                $count = (Select-String -Path $log.FullName -Pattern $keyword -SimpleMatch).Count
                $report += (" - {0,-7}: {1}" -f $keyword, $count) + "`r`n"
        }

        $report += "`r`n"
}



# File inventory add to CSV
$configFiles = Get-ChildItem -Path "network_configs" -Recurse -Include *.conf, *.rules

$inventory = @()
foreach ($file in $configFiles) {
        $parsedDate = Get-LastDate -FilePath $file.FullName
        $inventory += [PSCustomObject]@{
                Name         = $file.Name
                RelativePath = $file.FullName.Split("network_configs")[1].TrimStart("\\")
                SizeBytes    = $file.Length
                LastModified = if ($parsedDate -eq "UNKNOWN") { "UNKNOWN" } else { $parsedDate }
        }
}


# Export to CSV
$inventory | Export-Csv -Path "config_inventory.csv" -NoTypeInformation -Encoding UTF8



function Find-SecurityIssues {
        param (
                [string]$BasePath = "network_configs",
                [string]$OutputCsv = "security_review.csv"
        )

        # Patterns to search for
        $secPatterns = @(
                "password\s+\S+",         
                "secret\s+\S+",           
                "\bpublic\b",             
                "\bprivate\b",            
                "enable password\s+\S+"   
        )

        $results = @()

        # Collect all .conf and .rules files
        $files = Get-ChildItem -Path $BasePath -Recurse -Include *.conf, *.rules

        foreach ($file in $files) {
                foreach ($secPattern in $secPatterns) {
                        $secMatches = Select-String -Path $file.FullName -Pattern $secPattern -AllMatches
                        foreach ($secMatch in $secMatches) {
                                $results += [PSCustomObject]@{
                                        FileName     = $file.Name
                                        RelativePath = $file.FullName.Split($BasePath)[1].TrimStart("\\")
                                        LineNumber   = $secMatch.LineNumber
                                        Match        = $secMatch.Line.Trim()
                                        Pattern      = $secPattern
                                }
                        }
                }
        }

        # Export to CSV
        if ($results.Count -gt 0) {
                $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
                Write-Host "Security review finished. Results saved in $OutputCsv"
        }
        else {
                Write-Host "No security issues found."
        }
}

# Writes the information to the .txt report
$report | Out-File -FilePath "systems_analysis.txt" -Encoding UTF8