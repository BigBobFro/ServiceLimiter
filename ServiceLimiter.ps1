<#
Service Limiter for SCCM Software Installations

Originally written: Aug 4, 2014
Original Author: Victor Willingham (https://github.com/BigBobFro)

Dependancies: 		Powershell 2.0
					.NET 4.0
					PowerShell Execution Policy set to Bypass
					
Version History
Current Version 1.0 -- Aug 4, 2014
========================================
1.0 - New Script developed in Powershell 2.0

========================================
#>

param
(
	[string]$MI = $null													# Full path of main installer
	[string]$SN = $null													# Service name for service to limit
)

$srcPath = Split-Path -Path $MyInvocation.MyCommand.Path
$divider = "====================================================================================================================" 

# Setup Logging
$LogName = "ServiceLimiter($SN).log"
$LogPath = "C:\program files\fda\logs"
$LogFile = "$LogPath\$LogName"

If(-not(Test-Path -Path $LogPath) -eq $true)							# Create Directory if doesn't exist
	{New-Item -ItemType Directory -Path $LogPath}

# Attach to existing script log or create new script log if DNE
If(Test-Path -Path $LogFile) {"`n`n`n$divider" | Out-File -Filepath $logFile -Append}
Else {"$divider`n$divider" | Out-File -Filepath $logFile}

Function StopService
{
	param
	(
		[string]$SN = $null									# $sn= ServiceName
	)
	$svc = Get-Service -DisplayName $SN
    if(($svc.Status -like "Running") -or ($svc.status -like "Start*"))
    {
        "Service $SN Running.  Attempting to stop."| out-file -filepath $logfile -append
        stop-service $svc -PassThru
		start-sleep -s 10
        if ($svc.status -like "Stop") {"Service $SN stopped."| out-file -filepath $logfile -append}
        else {"Service $SN not stopped."| out-file -filepath $logfile -append}
    }
	else{"service stopped already." | out-file -filepath $logfile -append}
}

Function StartService
{
	param
	(
		[string]$SN = $null
	)
	$svc = Get-Service -DisplayName $SN
	Start-service $Svc -passthru
	start-sleep -s 10
	if (($svc.status -like "Running") -or ($svc.status -like "Start*"))
		{"Service $SN started" | out-file -filepath $logfile -append}
	else {"Service $sn did not start within the timeout period.  Please verify that it is enabled." | out-file -filepath $logfile -append}
}

if (($mi -eq $null) -or ($SN -eq $null))										# Handel the issue of no pass parameters
{
	"This utility is meant for use with a principle installer to keep a service turned off during install." | out-file -filepath $logfile -append
	if($mi -eq $null){"Please provide a full path to the primary installer and pass in the command line as -MI" | out-file -filepath $logfile -append}
	if($SN -eq $null){"Please provide the name of the service to be stopped in the command line as -SN" | out-file -filepath $logfile -append}
	$divider | out-file -filepath $logfile -append
	exit 0
}
else																			# Do the business
{
	# STOP Service PROCESS
	StopService($SN)
	"Initial Service Stopped" |out-file -filepath $logfile -append
	
	# Kick-off installer and capture object with $result
	$result = start-process $MI -passthru										# do not use wait for this!!

	if ($result -eq $null)
	{
		"Process: $MI`n`tExecution Failed."| out-file -filepath $logfile -append
		StartService($SN)
		exit 1
	}
	else
	{
		"Process: $MI`n`tExecution Success."| out-file -filepath $logfile -append
		$kwit = $False
		do
		{
			if ($result.HasExited) 
			{
				"Installation has exited.  Restarting service $SN." | out-file -filepath $logfile -append
				StartService($SN)
				$kwit = $True
				exit 0
			}
			else
			{
				"Installation has not yet finished.  Verifying service $SN is still stopped." | out-file -filepath $logfile -append
				StopService($SN)
				Start-Sleep -s 15
				$kwit = $False
			}
		} while( $kwit -ne $True)
	}
}
