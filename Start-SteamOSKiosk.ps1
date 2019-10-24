<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2017 v5.4.145
	 Created on:   	11/28/2017 7:40 PM
	 Filename:     	Start-SteamOSKiosk
	===========================================================================
	.DESCRIPTION
		SteamOS Big Picture Mode Watchdog. For Kiosk Setup.
#>

$SteamDir = Get-ChildItem -Path "$env:SystemDrive\Program Files (x86)\Steam\" -Filter "Steam.exe"
$SteamFolder = $SteamDir.DirectoryName
$SteamEXE = $SteamDir.fullname
$SteamVDF = "$SteamFolder\config\loginusers.vdf"
$attrib = "$env:windir\System32\attrib.exe"
$attribnorm = "-R $SteamVDF"
$attribread = "+R $SteamVDF"
$target = "Steam"
$DependProcess = "SteamService.exe", "steamwebhelper.exe", "Steam.exe"
$ArgList = "-tenfoot -silent -offline"
$unlockpwd = "secretpassword"

function test-internet
{
	[bool](Get-NetAdapter -Physical | Where-Object { $_.status -eq "Up" })
}

function set-networkmode
{
	if (test-internet)
	{
		Start-Process -FilePath $attrib -ArgumentList "$attribnorm"
		(Get-Content $SteamVDF) -replace '\"WantsOfflineMode\"\t\t\"1\"', '\"WantsOfflineMode\" \"0\"' | set-content -NoNewLine $SteamVDF
		(Get-Content $SteamVDF) -replace '\"SkipOfflineModeWarning\"\t\t\"1\"', '\"SkipOfflineModeWarning\" \"0\"' | set-content -NoNewLine $SteamVDF
		Start-Process -FilePath $attrib -ArgumentList "$attribread"
		start-steamos
	}
	Else
	{
		Start-Process -FilePath $attrib -ArgumentList "$attribnorm"
		(Get-Content $SteamVDF) -replace '\"WantsOfflineMode\"\t\t\"0\"', '\"WantsOfflineMode\" \"1\"' | set-content -NoNewLine $SteamVDF
		(Get-Content $SteamVDF) -replace '\"SkipOfflineModeWarning\"\t\t\"0\"', '\"SkipOfflineModeWarning\" \"1\"' | set-content -NoNewLine $SteamVDF
		Start-Process -FilePath $attrib -ArgumentList "$attribread"
		start-steamos
		
	}
}

function set-steamoffline
{
	Start-Process -FilePath $attrib -ArgumentList "$attribnorm"
	(Get-Content $SteamVDF) -replace '\"WantsOfflineMode\"\t\t\"0\"', '\"WantsOfflineMode\" \"1\"' | set-content -NoNewLine $SteamVDF
	(Get-Content $SteamVDF) -replace '\"SkipOfflineModeWarning\"\t\t\"0\"', '\"SkipOfflineModeWarning\" \"1\"' | set-content -NoNewLine $SteamVDF
	Start-Process -FilePath $attrib -ArgumentList "$attribread"
	start-steamos
}

function msg-input ($text)
{
	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
	[void][Microsoft.VisualBasic.Interaction]::InputBox("$text", "WatchDog Service", "")
}

function msg-box ($text)
{
	#Add-Type -AssemblyName "System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
	[void][System.Windows.Forms.MessageBox]::Show("$text", 'WatchDog Service') # Casting the method to [void] suppresses the output.
}

function prompt-question ($text)
{
	#Add-Type -AssemblyName "System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
	([System.Windows.Forms.MessageBox]::Show("$text", 'SteamOS Kiosk', [System.Windows.Forms.MessageBoxButtons]::YesNo))
} #End Function

function start-steamos
{
	if (!(get-steamprocess))
	{
		Start-Process -FilePath "$SteamEXE" -ArgumentList "$ArgList" -ErrorAction SilentlyContinue
	}
} #End Function

function kill-processes
{
	foreach ($proc in $DependProcess)
	{
		Stop-Process -Name $proc -Force -Confirm:$false -ErrorAction SilentlyContinue
	}
} #End Function

function get-steamprocess
{
	$script:process = Get-Process -Name Steam -ErrorAction Ignore
[bool](Get-Process -Name $target -ErrorAction Ignore)
}

####################################
####################################

while ($true)
{
	while (!(get-steamprocess))
	{
		#set-networkmode
		set-steamoffline
		start-sleep -s 5
		
	}
	if (get-steamprocess)
	{
		#What happens while process is running?
		#Waiting on process to close.
		$process.WaitForExit()
		start-sleep -s 5
		if (!(get-steamprocess))
		{
			#What happens on process exit?
			$prompt = prompt-question -text "Steam appears to be closed.`nRestart Service?"
			If ($prompt -eq "Yes")
			{
				start-steamos
				kill-processes
				Start-Sleep -s 15
				Clear-Variable -Name prompt -ErrorAction SilentlyContinue
			}
			elseif ($prompt -eq "No")
			{
				Clear-Variable -Name prompt -ErrorAction SilentlyContinue
				$prompt = prompt-question -text "Start Explorer for changes or troubleshooting? (Requires password)`nOtherwise workstation will restart."
				if ($prompt -eq "Yes")
				{
					Clear-Variable -Name prompt, count -ErrorAction SilentlyContinue
					$count = 0
					while ($true)
					{
						if ($count -ge 4)
						{
							msg-box -text "Computer will now restart."
							Restart-Computer -Force
						}
						
						$pwd = msg-input -text "Please enter the password required to start Explorer`nOtherwise failed logins will force workstation restart."
						If ($pwd -eq $unlockpwd)
						{
							Start-Process -FilePath c:\Windows\explorer.exe
							exit
						}
						else
						{
							Clear-Variable -Name pwd -ErrorAction SilentlyContinue
							$count ++
						}
					}
				}
				else
				{
					Clear-Variable -Name prompt
					msg-box -text "Computer will now restart."
					Restart-Computer -Force
				}
			}
		}
		
	}
}
