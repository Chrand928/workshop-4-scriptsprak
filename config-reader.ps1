###

$now = Get-Date "2024-10-14"

Get-ChildItem -Path "network_configs" -Recurse -Filter "*.conf" | 
Select-Object Name, @{Name = "SizeKB"; Expression = { [Math]::Round($_.Length / 1KB, 2) } }, LastWriteTime

Get-ChildItem -Path "network_configs" -Recurse -Filter "*.rules" |
Select-Object Name, @{Name = "SizeKB"; Expression = { [Math]::Round($_.Length / 1KB, 2) } }, LastWriteTime

Get-ChildItem -Path "network_configs" -Recurse -Filter "*.log" | 
Select-Object Name, @{Name = "SizeKB"; Expression = { [Math]::Round($_.Length / 1KB, 2) } }, LastWriteTime

