$workPassword = ConvertTo-SecureString "ChangeMe123!" -AsPlainText -Force
$homePassword = ConvertTo-SecureString "ChangeMe456!" -AsPlainText -Force

if (-not (Get-LocalUser -Name "home" -ErrorAction SilentlyContinue)) {
    New-LocalUser "home" -Password $homePassword -FullName "Home Profile"
}

if (-not (Get-LocalUser -Name "work" -ErrorAction SilentlyContinue)) {
    New-LocalUser "work" -Password $workPassword -FullName "Work Profile"
}

Add-LocalGroupMember -Group "Usuarios" -Member "home"
Add-LocalGroupMember -Group "Usuarios" -Member "work"