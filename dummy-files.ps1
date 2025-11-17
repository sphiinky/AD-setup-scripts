# Requires PowerShell running as Administrator AND the Active Directory Module.

# --- Configuration ---
$BaseProfilePath = "C:\Users"
$FilesPerType = 3

$FileDefinitions = @(
    @{ Folder = "Documents"; Ext = "docx"; Size = 2MB; NamePrefix = "Contract_V" },
    @{ Folder = "Documents"; Ext = "xlsx"; Size = 1MB; NamePrefix = "Report_Q" },
    @{ Folder = "Pictures"; Ext = "jpg"; Size = 3MB; NamePrefix = "IMG_HQ" },
    @{ Folder = "Pictures"; Ext = "png"; Size = 1MB; NamePrefix = "Screenshot" },
    @{ Folder = "Downloads"; Ext = "zip"; Size = 50MB; NamePrefix = "SoftwarePkg" },
    @{ Folder = "Desktop"; Ext = "txt"; Size = 5KB; NamePrefix = "Notes_ToDo" }
)

# --- Helper Function (Converts KB/MB to Bytes for fsutil) ---
function ConvertTo-Bytes {
    param([Parameter(Mandatory=$true)][string]$Size)
    $Size = $Size.ToUpper()
    if ($Size -match "MB") { return [long]($Size.Replace("MB", "") * 1MB) }
    if ($Size -match "KB") { return [long]($Size.Replace("KB", "") * 1KB) }
    return [long]$Size 
}

# --- 1. Identify Domain Users via Get-ADUser ---
Write-Host "Querying Active Directory for all Enabled Users..."

$ADUsers = Get-ADUser -Filter 'Enabled -eq $true' -Properties SamAccountName | 
    Where-Object { $_.SamAccountName -notin @('Administrator', 'Guest', 'krbtgt', 'DefaultAccount', 'HealthMailbox*') } |
    Select-Object -ExpandProperty SamAccountName

if ($ADUsers.Count -eq 0) {
    Write-Warning "No enabled Active Directory users found (excluding built-in accounts). Exiting."
    exit
}

Write-Host "Found $($ADUsers.Count) potential domain users to populate: $($ADUsers -join ', ')"
Write-Host "------------------------------------------------------------------"

# --- 2. Iterate and Populate Each Profile ---
foreach ($User in $ADUsers) {
    $UserPath = Join-Path -Path $BaseProfilePath -ChildPath $User
    
    # VITAL FIX: Force create the base profile folder if it doesn't exist
    if (-not (Test-Path $UserPath)) {
        try {
            # Use -Force to ensure creation and suppress errors if it already exists
            New-Item -Path $UserPath -ItemType Directory -Force | Out-Null
            Write-Host "NOTE: Creating base profile folder for $User (User has not logged in yet)." -ForegroundColor Yellow
        }
        catch {
            Write-Error "Failed to create base folder $UserPath. Check permissions."
            continue # Skip this user if the folder can't be created
        }
    }

    Write-Host "`nProcessing user: $User ($UserPath)"

    # Loop through each defined file type (e.g., DOCX, JPG)
    foreach ($File in $FileDefinitions) {
        # Fix for variable expansion error from prior session: ${User}
        $SubFolder = Join-Path -Path $UserPath -ChildPath $File.Folder
        
        # Create user subfolder (e.g., C:\Users\UserA\Documents)
        if (-not (Test-Path $SubFolder)) {
            New-Item -Path $SubFolder -ItemType Directory | Out-Null
        }

        # Create the required number of files for this type
        for ($i = 1; $i -le $FilesPerType; $i++) {
            $RandomID = Get-Random -Maximum 9999
            $FileName = "$($File.NamePrefix)$($i)_$($RandomID).$($File.Ext)"
            $FilePath = Join-Path -Path $SubFolder -ChildPath $FileName
            $SizeInBytes = ConvertTo-Bytes $File.Size
            
            # Use fsutil to create the file
            Write-Host "  -> Created: $FileName ($($File.Size))" -ForegroundColor Cyan
            $Result = cmd /c "fsutil file createnew `"$FilePath`" $SizeInBytes"
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "fsutil failed for $FilePath"
                break
            }
        }
    }
}

Write-Host "`n------------------------------------------------------------------"
Write-Host "Script execution complete. $(Get-Date -Format 'HH:mm:ss')"
