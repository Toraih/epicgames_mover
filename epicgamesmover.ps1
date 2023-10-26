# Init Vars
$statusColors = @{
    'err' = 'Red';
    'wrn'= 'Yellow';
    'inf' = 'White';
    'ok' = 'Green';
    'hl' = 'Cyan';
    'def' = 'Gray';
}

$debug = 1

# functions
function Output {
    param( [string]$message, [string]$status, [int]$blankLinesAfter = 0, [int]$blankLinesBefore = 0)
    if (-not ($status -in $statusColors.Keys)) { $status = 'def' }
	Write-Host -ForegroundColor $statusColors[$status] $message
    #1..$blankLinesBefore | ForEach-Object { Write-Output '' }
    #1..$blankLinesAfter | ForEach-Object { Write-Output '' }
}
function Debug {
    param( [string]$message, [string]$status, [int]$blankLinesAfter = 0, [int]$blankLinesBefore = 0)
    if ($debug -gt 0) {
        if (-not ($status -in $statusColors.Keys)) { $status = 'def' }
	    Write-Host -ForegroundColor $statusColors[$status] $message
        #1..$blankLinesBefore | ForEach-Object { Write-Output '' }
        #1..$blankLinesAfter | ForEach-Object { Write-Output '' }
    }
}

Output "Toraih's EpicGames Gamefolder mover" "hl" 1 1


# Check if running as administrator
$adminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $adminRights) {
	Output "Requesting Admin rights..."
    # Relaunch the script with elevated privileges
    Start-Process -FilePath PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Check if the Epic Games Launcher process is running
$epicLauncherProcess = Get-Process | Where-Object { $_.ProcessName -eq "EpicGamesLauncher" }
while ($epicLauncherProcess) {
	Output "EpicGamesLauncher is running. End the Launcher and try again." "err"
	Output 'Use System Tray: Find the Epic Games Launcher icon in the system tray (usually at the bottom right), right-click, and select "Exit" to close the launcher.' "inf"
	Output 'Or Task Manager: Press Win+X and select "Task Manager," find and select "EpicGamesLauncher" from the list of running applications, and click on "End Task" to close the Epic Games Launcher.'  "inf" 1
	$retry = Read-Host -Prompt "Retry? (Y/n)"
	if ($retry -eq 'n') {Exit}
	$epicLauncherProcess = Get-Process | Where-Object { $_.ProcessName -eq "EpicGamesLauncher" }
}

#########
# PATHS #
#########

# Leave $launcherInstalled and $manifestsFolder empty for automatic path finding, only change if it doesn't work
#
# My and most people default paths should be:
# $launcherInstalled = "C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
# $manifestsFolder = "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
$launcherInstalled = ""
$manifestsFolder = ""

$forceNewPath = ""
$filter = ''


# Auto Paths
$epicGamesLauncherData = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher").AppDataPath
if ($launcherInstalled -eq '') {
	Output "Searching for LauncherInstalled.dat..." 
	$launcherInstalled = (Get-Item $epicGamesLauncherData) | Split-Path -Parent | Split-Path -Parent
	$launcherInstalled += '\UnrealEngineLauncher\LauncherInstalled.dat'
}
if (Test-Path $launcherInstalled) {
	Output "Found: '$launcherInstalled'" "ok" 
} else {
	Output "Error: Could not find LauncherInstalled.dat ($launcherInstalled)" "err"
	Exit
}
if ($manifestsFolder -eq '') {
	Output "Searching for Manifests-folder..."
	$manifestsFolder = $epicGamesLauncherData + "Manifests"
}
if (Test-Path $manifestsFolder) {
	Output "Found: '$manifestsFolder'" "ok"
} else {
	Output "Error: Could not find Manifests-folder ($manifestsFolder)" "err"
	Exit
}
Output ""


Output "Searching EpicGames Libraryfolders..."

# Load the JSON content from the specified file
$jsonContent = Get-Content -Raw -Path $launcherInstalled | ConvertFrom-Json
$libraryList = @()
$defaultLibrary = 'C:\Program Files\Epic Games'
if (Test-Path -Path $defaultLibrary) {
	$libraryList += $defaultLibrary
	Output "Library found at: $defaultLibrary" "ok"
}

# choose gamefolders
$chosenNumbers = @()
while ($chosenNumbers.Count -eq 0) {
	$num = 0;
	$locationList = @()
	$missingList = @()
	$missing = "Missing Gamefolders:`n"
	$output = "@,Installation,Libraryfolder`n"

	# Display a list of InstallLocations starting with "$filter"
	for ($i = 0; $i -lt $jsonContent.InstallationList.Count; $i++) {
		$installLocation = $jsonContent.InstallationList[$i].InstallLocation
		if (-not (Test-Path -Path $installLocation)) {
			Output "Missing Gamefolder at: $installLocation" "wrn"
			$missingList += $installLocation
			$ii = $i + 1
			$missing += "$ii : $installLocation`n"
			Continue
		}
		$currentLocation = (Get-Item $installLocation) | Split-Path -Parent
		if (-not $libraryList.Contains($currentLocation)) {
			$libraryList += $currentLocation
			Output "Library found at: $currentLocation" "ok"
		}
		# Check if the InstallLocation starts with "$filter"
		if ($installLocation -like "$filter*") {
			if (-not $locationList.Contains($installLocation)) {
				$ii = $i + 1;
				# Extract the last part of the file path
				$installLocation = $installLocation.Replace('/', '\\')
				$lastPartOfPath = $installLocation -split '\\' | Select-Object -Last 1
				$output += "$ii,$lastPartOfPath,$currentLocation`n"
			}
			$locationList += $installLocation
		}
	}

	Output ""
	$csvData = $output | ConvertFrom-Csv
	$num = $locationList.Count;
	Output "$num Gamefolders found:"

	$csvData | Format-Table -AutoSize
	if ($missingList.Count -gt 0) {
		Output $missing
	}
	Output ""

	# Prompt the user to choose an installation number
	$promt = Read-Host -Prompt "Enter the installation number(s) to move"
	Output ""
	
	if ($promt -eq '') {
		$filter = ''
		Continue 
	}
	if ($promt -ieq 'exit') {
		Output "Canceled by user." "wrn" 1 1
		Exit 0 
	}
	if ([char]::IsLetter($promt.Substring(0, 1))) {
		$filter = $promt
		Continue 
	}
	# Split and convert the input to an integer
	if ($promt -match "\s") {
		$Numbers = $promt -split ' ' | ForEach-Object { [int]$_ }
		for ($i = 0; $i -lt $Numbers.Count; $i++) {
			$Number = $Numbers[$i] - 1
			if ($Number -ge 0 -and $Number -lt $jsonContent.InstallationList.Count) {
				$installLocation = $jsonContent.InstallationList[$Number].InstallLocation
				if ($locationList.Contains($installLocation)) {
					$chosenNumbers += $Number
					Output "Selected: $installLocation"
				} else {
					Output "Invalid selection: $i" "wrn"
				}
			} else {
				Output "Invalid selection" "wrn"
			}
		}
	} else {
		$promt = $promt - 1
		if ($promt -ge 0 -and $promt -lt $jsonContent.InstallationList.Count) {
			$installLocation = $jsonContent.InstallationList[$promt].InstallLocation
			$chosenNumbers += $promt
			Output "Selected: $installLocation"
		} else {
			Output "Invalid selection: $promt" "wrn"
		}
	}
}

# choose destination library
$newLibrary = ''
while ($newLibrary -eq '') {
	$output = "@,Library`n"
	$output+= "0,Input custom path...`n"
	$nl = 1;
	for ($i = 0; $i -lt $libraryList.Count; $i++) {
		$library = $libraryList[$i] 
		if (-not ($currentLibrary -eq $library -or $library -eq '')) {
			$ii = $i + 1;
			$nl += 1;
			$output += "$ii,$library`n"
		}
	}
	$csvData = $output | ConvertFrom-Csv
	$csvData | Format-Table -AutoSize

	$chosenLibrary = Read-Host -Prompt "Choose the destination library" 
	if ($chosenLibrary -ieq 'exit') {
		Output "Canceled by user." "wrn" 1 1
		Exit 0 
	}
	$chosenLibrary = [int]$chosenLibrary
	if ($chosenLibrary -eq 0) {
		$newPath = Read-Host -Prompt "Enter the library-path" 
		if ($newPath.Length -eq 0 -or -not (Test-Path -Path $newPath)) {
			Output "Library-path not found at: $newPath" "err"
			Output "The path must exist!" "err" 1
			Continue
		}
		
	}
	if ($chosenLibrary -gt 0 -and $chosenLibrary -lt $nl) {
		$chosenLibrary = $chosenLibrary-1
		$newLibrary = $libraryList[$chosenLibrary]
		$_newLibrary = $newLibrary.Replace('\', '\\')
	}
}

# Display confirmation for the chosen installation location
Output ""
Write-Host "You have chosen to move the installations:" -ForegroundColor Yellow
$newDrive = $newLibrary.Substring(0, 1)
$freeSpace = (Get-PSDrive -Name $newDrive | Select-Object -ExpandProperty Free).ToString()
$_freeSpace = "{0:N2} GB" -f ($freeSpace / 1GB)
$freeMB = ($freeSpace / 1MB)
Write-Host "Free space at destination: $_freeSpace" -ForegroundColor Cyan
for ($i = 0; $i -lt $chosenNumbers.Count; $i++) {
	$chosenNumber = $chosenNumbers[$i]
	
	$oldLocation = $jsonContent.InstallationList[$chosenNumber].InstallLocation	
	$_oldLocation = $oldLocation.Replace('\', '\\').Replace('/', '\\')
	$name = $_oldLocation -split '\\' | Select-Object -Last 1
	$oldDrive = $oldLocation.Substring(0, 1)
	
	#$currentLibrary = (Get-Item $oldLocation) | Split-Path -Parent
	
	# Replace the old path with the new path in the installation location
	#$_newLocation = $oldLocation.Replace($currentLibrary, $newLibrary)
	$_newLocation = "$newLibrary\\$name"

	# Replace double and single backslashes with a temporary character '|', then restore the original backslashes (to convert single backslashes to double)
	$newLocation = $_newLocation.Replace('\\', '|').Replace('\', '|').Replace('|', '\\')
	
	if (Test-Path -Path $oldLocation) {
		$totalSize = ((Get-ChildItem -Path $oldLocation -Recurse | Measure-Object -Property Length -Sum).Sum)
		$_totalSize = "{0:N2} GB" -f ($totalSize / 1GB)
		$_totalMB = ($totalSize / 1MB)
		if ($newDrive -ne $oldDrive) {
			$freeMB -= $_totalMB
		}
		$_freeSpace = "{0:N2} GB" -f ($freeMB / 1KB)
	} 
	if (Test-Path -Path $newLocation) {
		$totalSize = ((Get-ChildItem -Path $newLocation -Recurse | Measure-Object -Property Length -Sum).Sum)
		$_totalSize = "{0:N2} GB" -f ($totalSize / 1GB)
		$_totalMB = ($totalSize / 1MB)
		$_freeSpace = "{0:N2} GB" -f ($freeMB / 1KB)
	}
	
	Write-Host "from: $oldLocation" -ForegroundColor Cyan
	Write-Host "to: $_newLocation" -ForegroundColor Cyan
	Write-Host "size: $_totalSize" -ForegroundColor Cyan
	Write-Host "Free space after: $_freeSpace" -ForegroundColor Cyan
	Output ""

}

# Display confirmation for the chosen installation location
Output ""
$confirmation = Read-Host -Prompt "Are you sure you want to start the moving process? (yes/NO)"
if ($confirmation -ieq 'exit') {
	Output "Canceled by user." "wrn" 1 1
	Exit 0 
}
if ($confirmation -ieq "yes") {

	# Move the folder to the new location
	Output "Moving choosen installations... (do not interupt until done)"

	foreach ($chosenNumber in $chosenNumbers) {
			
		if ($chosenNumber -ge 0 -and $chosenNumber -lt $jsonContent.InstallationList.Count) {
			$oldLocation = $jsonContent.InstallationList[$chosenNumber].InstallLocation
			$_oldLocation = $oldLocation.Replace('\', '\\').Replace('/', '\\')
			$name = $_oldLocation -split '\\' | Select-Object -Last 1
			$_newLocation = "$newLibrary\\$name"
			# Replace double and single backslashes with a temporary character '|', then restore the original backslashes (to convert single backslashes to double)
			$newLocation = $_newLocation.Replace('\\', '|').Replace('\', '|').Replace('|', '\\')
			Output ""
			if (-not (Test-Path -Path $oldLocation)) {
				Output "Gamefolder missing at: $oldLocation" "err"
				if (Test-Path -Path $newLocation) {
					Output "Gamefolder found at: $newLocation" "inf"
					$totalMB = ((Get-ChildItem -Path $newLocation -Recurse | Measure-Object -Property Length -Sum).Sum)/1MB
					Output "Gamefolder size: $totalMB MB"
					if ($totalMB -ge 5) {
						$success = 1
					}
				} else {
					Output "Gamefolder not found at: $newLocation" "err"
					Output "Skipping..." "inf"
				}
			} else {

				Output "Move installation from $oldLocation to $newLocation..."
				$totalMB = ((Get-ChildItem -Path $oldLocation -Recurse | Measure-Object -Property Length -Sum).Sum)/1MB

				# Start a background job to move the item
				$job = Start-Job -ScriptBlock {
					param ([string]$source, [string]$destination)
					return (Move-Item -Path $source -Destination $destination)
				} -ArgumentList $oldLocation, $_newLibrary

				# Monitor the job until it's completed
				$s = 0;
				do {
					Start-Sleep -Milliseconds 500
					$jobState = $job.State
					$s += 1
					if ($s % 4 -eq 0) {
						Write-Host "." -noNewline
					}
					if ($s % 240 -eq 0) {
						Write-Output ""
					}
				} while ($jobState -eq 'Running')
				$s = $s / 2

				# Check if the job completed successfully
				if ($jobState -eq 'Completed') {
					$mbs = $totalMB/$s
					$success = $true
					Write-Output "`nMove completed successfully. ~ $s s | $mbs MB/s"
				} else {
					$success = $false
					Write-Output "`nMove failed with state: $jobState"
				}

				# Retrieve any output from the job
				$joboutput = Receive-Job -Job $job
				if ($joboutput -ne '') {
					Write-Output "Job output: $joboutput"
				}

				# Clean up the job
				Remove-Job -Job $job
			}

			if ($success) {
				Output "Folder moved from $oldLocation to $newLocation."

				# Update InstallLocation with NewLocation in the file content
				$fileContent = Get-Content -Raw -Path $launcherInstalled
				$fileContent = $fileContent.Replace($oldLocation, $newLocation)
				$fileContent = $fileContent.Replace($_oldLocation, $newLocation)

				# Save the updated content back to the file
				$fileContent | Set-Content -Path $launcherInstalled -Force

				Output "InstallLocation updated in Manifest-file: $launcherInstalled"

				# Search and replace InstallLocation with newLocation in all files in the specified folder
				Get-ChildItem -Path $manifestsFolder -Filter *.item | ForEach-Object {
					$fileContent = Get-Content -Raw -Path $_.FullName
					$_fileContent = $fileContent.Replace($oldLocation, $newLocation)
					$_fileContent = $_fileContent.Replace($_oldLocation, $newLocation)
					if ($fileContent -ne $_fileContent) {
						$_fileContent | Set-Content -Path $_.FullName -Force
						Output "InstallLocation updated in file: $($_.FullName)"
					}
				}

				Output "Done" "hl" 1
			} else {
				Output "Error: Moving failed or incomplete" "err" 1 1
				Break
			}
		} else {
			Output "Invalid installation number." "wrn" 1
		}
	}
} else {
	Output "Operation canceled by user." "wrn" 1 1
}
$restart = Read-Host -Prompt "Restart? (y/N)"
if ($restart -ieq 'y') {
    Start-Process -FilePath PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
}