Write-Host "Configuring users..."
.\users.ps1

Write-Host "Installing work packages..."
winget import -i packages-work.json