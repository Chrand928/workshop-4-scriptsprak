###

function Get-LastDate {
        return "2024-10-14"
}

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

$report += @"
===============================
        SYSTEMS ANALYSIS
===============================

FILE OVERVIEW
------------------------------------
"@

# Creates a list of the files and adds it to the report
$formattedFiles = $allFiles | Select-Object `
@{Name = "File Name"; Expression = { $_.Name } },
@{Name = "Size (KB)"; Expression = { [Math]::Round($_.Length / 1KB, 2) } },
@{Name = "Last Update"; Expression = {
                $lastDate = Get-LastDate -FilePath $_.FullName
                if ($lastDate -eq "UNKNOWN") { "UNKNOWN" } else { $lastDate }
        }
} |
Format-Table -AutoSize | Out-String

$report += $formattedFiles

# Writes the information to the .txt report
$report | Out-File -FilePath "systems_analysis.txt" -Encoding UTF8