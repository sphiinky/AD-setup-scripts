# 1. Install the WSUS role with the Windows Internal Database (WID) option.
# This also installs the necessary IIS components.
Install-WindowsFeature -Name UpdateServices, Windows-Internal-Database -IncludeManagementTools

# 2. Get the installation location for the WSUS configuration executable.
$WsusSetupPath = Get-ChildItem -Path "C:\Program Files\Update Services\Tools" -Filter "WsusUtil.exe" | Select-Object -ExpandProperty FullName

# 3. Define the content directory (where updates will be stored)
$ContentDir = "C:\WSUS_Content"

# 4. Create the content directory if it doesn't exist
if (-not (Test-Path $ContentDir)) {
    New-Item -Path $ContentDir -ItemType Directory | Out-Null
}

Write-Host "WSUS Role installed successfully. Starting initial configuration..."

# Run the post-installation tasks for WSUS.
# - The /contentdir switch specifies where update files will be stored.
# - The /log switch can be used to capture the output to a file for troubleshooting.
& $WsusSetupPath postinstall /contentdir $ContentDir /log "C:\WSUS_Content\WsusPostInstall.log"

# Note: The /targetdir and /instancename switches may be needed if using a remote SQL Server, 
# but are omitted here for the default WID setup.

Write-Host "WSUS Post-installation complete."
Write-Host "You can now configure synchronization and client settings via the WSUS Console."
