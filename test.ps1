#Get-ChildItem -Filter "*.log" -Recurse | 
#Select-String -Pattern "ERROR"

# Hittar alla IP adresser
#Get-ChildItem -Filter "*.conf" -Recurse |
#Select-String -Pattern "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}"


#Get-ChildItem -Recurse |
#Group-Object -Property Extension


# -File visar endast filer
# T.ex. -Directory visar endast mappar
#$byFileType = Get-ChildItem -File -Path "network_configs" -Recurse |
#Group-Object -Property Extension

#Write-Host "FILTYPER OCH ANTAL"
#Write-Host $("-" * 40)
#foreach ($type in $byFileType) {
#    Write-Host "$($type.Name): $($type.Count) st"
#}

