Import-Module WebAdministration
Import-Module AWSPowerShell

# Execute the AWS CLI command to get the parameter values
$appPoolNameToolCore = Get-SSMParameter -Name "appPoolNameToolCore" -WithDecryption 1 | Select -ExpandProperty ‘Value’
$appPoolName = Get-SSMParameter -Name "appPoolName" -WithDecryption 1 | Select -ExpandProperty ‘Value’
$siteName = Get-SSMParameter -Name "siteName" -WithDecryption 1 | Select -ExpandProperty ‘Value’
$appPoolUsername = Get-SSMParameter -Name "appPoolUsername" -WithDecryption 1 | Select -ExpandProperty ‘Value’
$appPoolPassword = Get-SSMParameter -Name "appPoolPassword" -WithDecryption 1 | Select -ExpandProperty ‘Value’
$appPath = Get-SSMParameter -Name "appPath" -WithDecryption 1 | Select -ExpandProperty ‘Value’

$iisAppPoolDotNetVersion = ""

function getToolCoreRestartSchedule {
    param(
    [Parameter(Mandatory=$true)]
    [string]$appPoolName
    )
    cd IIS:\AppPools\

    $toolCoreSchedule = (Get-ItemProperty "IIS:\AppPools\$appPoolName" -Name "recycling.periodicRestart.schedule[0]")
    $toolCorePeriodicRestartSchedule = $ToolCoreSchedule.value
    $newScheduleTime = $toolCorePeriodicRestartSchedule.Add([TimeSpan]::FromMinutes(15))
    $newScheduleTimeString = $newScheduleTime.ToString()
    return $newScheduleTimeString

} 

function createAppPool {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appPoolName,
        [string]$appPoolUsername,
        [string]$appPoolPassword,
        [string]$scheduleTime
    )

    cd IIS:\AppPools\

    if (!(Test-Path $appPoolName -pathType container))
    {
        #create the app pool
        $appPool = New-Item $appPoolName
        $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $iisAppPoolDotNetVersion
        $appPool | Set-ItemProperty -Name "startMode" -Value "AlwaysRunning"
        $appPool | Set-ItemProperty -Name "processModel" -Value @{userName=$appPoolUsername;password=$appPoolPassword;identitytype=3}
        $appPool | Set-ItemProperty -Name "processModel" -Value @{IdleTimeout="00:00:00"}
        $appPool | Set-ItemProperty -Name "processModel" -Value @{idleTimeoutAction=0}
        $appPool | Set-ItemProperty -Name "recycling" -Value @{disallowOverlappingRotation="true"}
        $appPool | Set-ItemProperty -Name "recycling.periodicRestart" -Value @{time="00:00:00"}
        $appPool | Set-ItemProperty -Name "recycling.periodicRestart.schedule" -Value @{value = $scheduleTime}
    }
}


function createApp {
    param(
    [Parameter(Mandatory=$true)]
    [string]$appPoolName,
    [string]$siteName,
    [string]$appPath,
    [string]$physicalPath = "W:\Websites\SurveyInterface"
    )

    cd IIS:\Sites\

    if (-not (Test-Path $physicalPath)) {
        New-Item -ItemType Directory -Path $physicalPath -Force
    }
    New-WebApplication -Name $appPath -Site $siteName -PhysicalPath $physicalPath -ApplicationPool $appPoolName

}


$newScheduleTimeString = getToolCoreRestartSchedule -appPoolName $appPoolNameToolCore
createAppPool -appPoolName $appPoolName -appPoolUsername $appPoolUsername -appPoolPassword $appPoolPassword -scheduleTime $newScheduleTimeString
createApp -appPoolName $appPoolName -siteName $siteName -appPath $appPath
