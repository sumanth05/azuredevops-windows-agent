<#
    Microsoft.TeamFoundation.DistributedTask.Task.Deployment.Internal.psm1
#>

# Constants #
$buildUriConstant = '/_build#_a=summary&buildId='

# TELEMETRY CODES
$telemetryCodes = 
@{
  "PREREQ_NoWinRMHTTP_Port" = "PREREQ001";
  "PREREQ_NoWinRMHTTPSPort" = "PREREQ002";
  "PREREQ_NoResources" = "PREREQ003";
  "PREREQ_NoOutputVariableForSelectActionInAzureRG" = "PREREQ004";
  "PREREQ_InvalidServiceConnectionType" = "PREREQ_InvalidServiceConnectionType";
  "PREREQ_AzureRMModuleNotFound" = "PREREQ_AzureRMModuleNotFound";
  "PREREQ_InvalidFilePath" = "PREREQ_InvalidFilePath";
  "PREREQ_StorageAccountNotFound" = "PREREQ_StorageAccountNotFound";
  "PREREQ_NoVMResources" = "PREREQ_NoVMResources";
  "PREREQ_UnsupportedAzurePSVerion" = "PREREQ_UnsupportedAzurePSVerion"; 
  "PREREQ_ClassicStorageAccountNotFound" = "PREREQ_ClassicStorageAccountNotFound";
  
  "PREREQ_RMStorageAccountNotFound" = "PREREQ_RMStorageAccountNotFound";
  
  "PREREQ_NoClassicVMResources" = "PREREQ_NoClassicVMResources";
  
  "PREREQ_NoRMVMResources" = "PREREQ_NoRMVMResources";
  
  "PREREQ_ResourceGroupNotFound" = "PREREQ_ResourceGroupNotFound";

  "AZUREPLATFORM_BlobUploadFailed" = "AZUREPLATFORM_BlobUploadFailed";
  "AZUREPLATFORM_UnknownGetRMVMError" = "AZUREPLATFORM_UnknownGetRMVMError";

  "UNKNOWNPREDEP_Error" = "UNKNOWNPREDEP001";
  "UNKNOWNDEP_Error" = "UNKNOWNDEP_Error";

  "DEPLOYMENT_Failed" = "DEP001";
  "DEPLOYMENT_FetchPropertyFromMap" = "DEPLOYMENT_FetchPropertyFromMap";
  "DEPLOYMENT_CSMDeploymentFailed" = "DEPLOYMENT_CSMDeploymentFailed";  
  "DEPLOYMENT_PerformActionFailed" = "DEPLOYMENT_PerformActionFailed";

  "FILTERING_IncorrectFormat" = "FILTERING_IncorrectFormat";
  "FILTERING_NoVMResources" = "FILTERING_NoVMResources";
  "FILTERING_MachinesNotPresentInRG" = "FILTERING_MachinesNotPresentInRG"
 }

### These constants are copied from 'Microsoft.VisualStudio.Services.DevTestLabs.Common.dll'
### [Microsoft.VisualStudio.Services.DevTestLabs.Common.DevTestLabsConstants]::WINRM_HttpTagKey - This code has been removed to remove the dependency of this psm1 with dll
$WINRM_HttpTagKey = "WinRM_Http";
$WINRM_HttpsTagKey = "WinRM_Https";
$FQDNTagKey = "Microsoft-Vslabs-MG-Resource-FQDN";
$SkipCACheckTagKey = "Microsoft-Vslabs-MG-SkipCACheck";

 # TELEMETRY FUNCTION
function Write-Telemetry
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$codeKey,

    [Parameter(Mandatory=$True,Position=2)]
    [string]$taskId
    )
  
  if($telemetrySet)
  {
    return
  }

  $code = $telemetryCodes[$codeKey]
  $telemetryString = "##vso[task.logissue type=error;code=" + $code + ";TaskId=" + $taskId + ";]"
  Write-Host $telemetryString
  $telemetrySet = $true
}

function Get-ResourceCredentials
{
    [CmdletBinding()]
    Param
    (
        [object]$resource
    )

    $machineUserName = $resource.Username
    if([string]::IsNullOrWhiteSpace($machineUserName))
    {
        throw (Get-LocalizedString -Key "Please specify valid username for resource {0}" -ArgumentList $resource.Name)
    }
    Write-Verbose "`t`t Resource Username - $machineUserName"
    
    $machinePassword = $resource.Password
    if([string]::IsNullOrWhiteSpace($machinePassword))
    {
        throw (Get-LocalizedString -Key "Please specify valid password for resource {0}" -ArgumentList $resource.Name)
    }

    $credential = New-Object 'System.Net.NetworkCredential' -ArgumentList $machineUserName, $machinePassword

    return $credential
}

function Get-ResourceOperationLogs
{
    [CmdletBinding()]
    Param
    (
        [object] [Parameter(Mandatory = $true)]
        $deploymentResponse
    )

    $log = "Copy Logs : " + $deploymentResponse.DeploymentLog + "`nService Logs : " + $deploymentResponse.ServiceLog;

    $logs = New-Object 'System.Collections.Generic.List[System.Object]'
    $resourceOperationLog = New-OperationLog -Content $log
    $logs.Add($resourceOperationLog)

    return $logs
}

function Write-ResponseLogs
{
    [CmdletBinding()]
    Param
    (
        [string] [Parameter(Mandatory = $true)]
        $operationName,

        [string] [Parameter(Mandatory = $true)]
        $fqdn,

        [object] [Parameter(Mandatory = $true)]
        $deploymentResponse
    )

    Write-Verbose "Finished $operationName operation on $fqdn"

    if ([string]::IsNullOrEmpty($deploymentResponse.DeploymentLog) -eq $false)
    {
        Write-Verbose "Deployment logs for $operationName operation on $fqdn " -Verbose
        Write-Verbose ($deploymentResponse.DeploymentLog | Format-List | Out-String) -Verbose
    }

    if ([string]::IsNullOrEmpty($deploymentResponse.ServiceLog) -eq $false)
    {
        Write-Verbose "Service logs for $operationName operation on $fqdn "
        Write-Verbose ($deploymentResponse.ServiceLog | Format-List | Out-String)
    }
}

function Get-ResourceHttpTagKey
{
    [CmdletBinding()]
    Param
    ()

    return $WINRM_HttpTagKey
}

function Get-ResourceHttpsTagKey
{
    [CmdletBinding()]
    Param
    ()

    return $WINRM_HttpsTagKey
}

function Get-ResourceFQDNTagKey
{
    [CmdletBinding()]
    Param
    ()

    return $FQDNTagKey
}

function Get-SkipCACheckTagKey
{
    [CmdletBinding()]
    Param
    ()

    return $SkipCACheckTagKey
}

function Get-OperationLogs
{
    [CmdletBinding()]
    param
    ()

    $teamFoundationCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    $teamProject = $env:SYSTEM_TEAMPROJECT
    $buildId = $env:BUILD_BUILDID
    #TODO: Need to fix this URL for Release.
    $buildUri = $teamFoundationCollectionUri + $teamProject + $buildUriConstant + $buildId

    $logs = New-Object 'System.Collections.Generic.List[System.Object]'
    $resourceOperationLog = New-OperationLog -Content $buildUri
    $logs.Add($resourceOperationLog)
    return $logs
}

function Get-SqlPackageCommandArguments
{
    param (
    [string]$dacpacFile,
    [string]$targetMethod,
    [string]$serverName,
    [string]$databaseName,
    [string]$sqlUsername,
    [string]$sqlPassword,
    [string]$connectionString,
    [string]$publishProfile,
    [string]$additionalArguments
    )

    $ErrorActionPreference = 'Stop'
    $dacpacFileExtension = ".dacpac"
    $SqlPackageOptions =
    @{
        SourceFile = "/SourceFile:"; 
        Action = "/Action:"; 
        TargetServerName = "/TargetServerName:";
        TargetDatabaseName = "/TargetDatabaseName:";
        TargetUser = "/TargetUser:";
        TargetPassword = "/TargetPassword:";
        TargetConnectionString = "/TargetConnectionString:";
        Profile = "/Profile:";
    }

    # validate dacpac file
    if ([System.IO.Path]::GetExtension($dacpacFile) -ne $dacpacFileExtension)
    {
        Write-Error (Get-LocalizedString -Key "Invalid Dacpac file '{0}' provided" -ArgumentList $dacpacFile)
    }

    $sqlPackageArguments = @($SqlPackageOptions.SourceFile + "`'$dacpacFile`'")
    $sqlPackageArguments += @($SqlPackageOptions.Action + "Publish")

    if($targetMethod -eq "server")
    {
        $sqlPackageArguments += @($SqlPackageOptions.TargetServerName + "`'$serverName`'")

        if ($databaseName)
        {
            $sqlPackageArguments += @($SqlPackageOptions.TargetDatabaseName + "`'$databaseName`'")
        }

        if($sqlUsername)
        {
            $sqlPackageArguments += @($SqlPackageOptions.TargetUser + "`'$sqlUsername`'")

            if (-not($sqlPassword))
            {
                Write-Error (Get-LocalizedString -Key "No password specified for the SQL User: '{0}'" -ArgumentList $sqlUserName)
            }

            $sqlPackageArguments += @($SqlPackageOptions.TargetPassword + "`'$sqlPassword`'")
        }    
    }
    elseif($targetMethod -eq "connectionString")
    {
        $sqlPackageArguments += @($SqlPackageOptions.TargetConnectionString + "`'$connectionString`'")
    }    

    if( [string]::IsNullOrWhitespace($PublishProfile) -eq $false -and $PublishProfile -ne $env:SYSTEM_DEFAULTWORKINGDIRECTORY -and $PublishProfile -ne [String]::Concat($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "\"))
    {
        # validate publish profile
        if ([System.IO.Path]::GetExtension($publishProfile) -ne ".xml")
        {
            Write-Error (Get-LocalizedString -Key "Invalid Publish Profile '{0}' provided" -ArgumentList $publishProfile)
        }
        $sqlPackageArguments += @($SqlPackageOptions.Profile + "`'$publishProfile`'")
    }

    $sqlPackageArguments += @("$additionalArguments")

    $scriptArgument = '"' + ($sqlPackageArguments -join " ") + '"'

    return $scriptArgument
}
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCFUQ6Jbzpjnr9R
# vlfQAohpN4cE8boJDoOT7D3DcoNzLaCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
# DkyjTQVBAAAAAAOvMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwOTAwWhcNMjQxMTE0MTkwOTAwWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOS8s1ra6f0YGtg0OhEaQa/t3Q+q1MEHhWJhqQVuO5amYXQpy8MDPNoJYk+FWA
# hePP5LxwcSge5aen+f5Q6WNPd6EDxGzotvVpNi5ve0H97S3F7C/axDfKxyNh21MG
# 0W8Sb0vxi/vorcLHOL9i+t2D6yvvDzLlEefUCbQV/zGCBjXGlYJcUj6RAzXyeNAN
# xSpKXAGd7Fh+ocGHPPphcD9LQTOJgG7Y7aYztHqBLJiQQ4eAgZNU4ac6+8LnEGAL
# go1ydC5BJEuJQjYKbNTy959HrKSu7LO3Ws0w8jw6pYdC1IMpdTkk2puTgY2PDNzB
# tLM4evG7FYer3WX+8t1UMYNTAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQURxxxNPIEPGSO8kqz+bgCAQWGXsEw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMTgyNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAISxFt/zR2frTFPB45Yd
# mhZpB2nNJoOoi+qlgcTlnO4QwlYN1w/vYwbDy/oFJolD5r6FMJd0RGcgEM8q9TgQ
# 2OC7gQEmhweVJ7yuKJlQBH7P7Pg5RiqgV3cSonJ+OM4kFHbP3gPLiyzssSQdRuPY
# 1mIWoGg9i7Y4ZC8ST7WhpSyc0pns2XsUe1XsIjaUcGu7zd7gg97eCUiLRdVklPmp
# XobH9CEAWakRUGNICYN2AgjhRTC4j3KJfqMkU04R6Toyh4/Toswm1uoDcGr5laYn
# TfcX3u5WnJqJLhuPe8Uj9kGAOcyo0O1mNwDa+LhFEzB6CB32+wfJMumfr6degvLT
# e8x55urQLeTjimBQgS49BSUkhFN7ois3cZyNpnrMca5AZaC7pLI72vuqSsSlLalG
# OcZmPHZGYJqZ0BacN274OZ80Q8B11iNokns9Od348bMb5Z4fihxaBWebl8kWEi2O
# PvQImOAeq3nt7UWJBzJYLAGEpfasaA3ZQgIcEXdD+uwo6ymMzDY6UamFOfYqYWXk
# ntxDGu7ngD2ugKUuccYKJJRiiz+LAUcj90BVcSHRLQop9N8zoALr/1sJuwPrVAtx
# HNEgSW+AKBqIxYWM4Ev32l6agSUAezLMbq5f3d8x9qzT031jMDT+sUAoCw0M5wVt
# CUQcqINPuYjbS1WgJyZIiEkBMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIH0TVyrC3RliUwZnqcNU8315
# LM35Npg1gjgvdjQWOln8MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAdcURbhAgPNWQyBM99rzB6a0Lf0N1KPYHfVMKPndV7uNJ4foRoBBEy4Fx
# sx09eS048DsFH9VNL6SKW5N86y+efbdV7gzCS6A4T9XUCLe9Adl8TWltr1aM/8pf
# Pnra87RorCZyx3lRlqELsh6oBP3IRIh89XEKQlX2ofjty3ums//SPR6PgpVWuz0z
# PQ3ZSjd182gD7uYcLC0LIrT/EhRltIWCK+8nDDf1LUwXLHoyifu+yrdMWhF2MVdI
# 8njd0efuzJ6CUPqBORDMkH1CzjLXi7Fw1l0gZpyylbKcO644DCbRKyPC7Z7+ewtu
# G8Yu9sCaZx9KJHFQkcEHXvk/PUOrSKGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBzS2I9WVDuomwhAnmZriL0vDy1JEXrl8Kdqs+w+VbaggIGZfMs4WYu
# GBMyMDI0MDQwOTE2MzQ0MC45MDdaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RTAwMi0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAe4F0wIwspqdpwABAAAB7jANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1
# NDRaFw0yNTAzMDUxODQ1NDRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RTAwMi0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC+8byl16KEia8xKS4vVL7REOOR7LzYCLXEtWgeqyOV
# lrzuEz+AoCa4tBGESjbHTXECeMOwP9TPeKaKalfTU5XSGjpJhpGx59fxMJoTYWPz
# zD0O2RAlyBmOBBmiLDXRDQJL1RtuAjvCiLulVQeiPI8V7+HhTR391TbC1beSxwXf
# dKJqY1onjDawqDJAmtwsA/gmqXgHwF9fZWcwKSuXiZBTbU5fcm3bhhlRNw5d04Ld
# 15ZWzVl/VDp/iRerGo2Is/0Wwn/a3eGOdHrvfwIbfk6lVqwbNQE11Oedn2uvRjKW
# EwerXL70OuDZ8vLzxry0yEdvQ8ky+Vfq8mfEXS907Y7rN/HYX6cCsC2soyXG3OwC
# tLA7o0/+kKJZuOrD5HUrSz3kfqgDlmWy67z8ZZPjkiDC1dYW1jN77t5iSl5Wp1HK
# Bp7JU8RiRI+vY2i1cb5X2REkw3WrNW/jbofXEs9t4bgd+yU8sgKn9MtVnQ65s6QG
# 72M/yaUZG2HMI31tm9mooH29vPBO9jDMOIu0LwzUTkIWflgd/vEWfTNcPWEQj7fs
# WuSoVuJ3uBqwNmRSpmQDzSfMaIzuys0pvV1jFWqtqwwCcaY/WXsb/axkxB/zCTdH
# SBUJ8Tm3i4PM9skiunXY+cSqH58jWkpHbbLA3Ofss7e+JbMjKmTdcjmSkb5oN8qU
# 1wIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFBCIzT8a2dwgnr37xd+2v1/cdqYIMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQB3ZyAva2EKOWSVpBnYkzX8f8GZjaOs577F
# 9o14Anh9lKy6tS34wXoPXEyQp1v1iI7rJzZVG7rpUznay2n9csfn3p6y7kYkHqtS
# ugCGmTiiBkwhFfSByKPI08MklgvJvKTZb673yGfpFwPjQwZeI6EPj/OAtpYkT7IU
# XqMki1CRMJKgeY4wURCccIujdWRkoVv4J3q/87KE0qPQmAR9fqMNxjI3ZClVxA4w
# iM3tNVlRbF9SgpOnjVo3P/I5p8Jd41hNSVCx/8j3qM7aLSKtDzOEUNs+ZtjhznmZ
# gUd7/AWHDhwBHdL57TI9h7niZkfOZOXncYsKxG4gryTshU6G6sAYpbqdME/+/g1u
# er7VGIHUtLq3W0Anm8lAfS9PqthskZt54JF28CHdsFq/7XVBtFlxL/KgcQylJNni
# a+anixUG60yUDt3FMGSJI34xG9NHsz3BpqSWueGtJhQ5ZN0K8ju0vNVgF+Dv05si
# rPg0ftSKf9FVECp93o8ogF48jh8CT/B32lz1D6Truk4Ezcw7E1OhtOMf7DHgPMWf
# 6WOdYnf+HaSJx7ZTXCJsW5oOkM0sLitxBpSpGcj2YjnNznCpsEPZat0h+6d7ulRa
# WR5RHAUyFFQ9jRa7KWaNGdELTs+nHSlYjYeQpK5QSXjigdKlLQPBlX+9zOoGAJho
# Zfrpjq4nQDCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkUwMDItMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCI
# o6bVNvflFxbUWCDQ3YYKy6O+k6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6b9HqTAiGA8yMDI0MDQwOTA0NTA0
# OVoYDzIwMjQwNDEwMDQ1MDQ5WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDpv0ep
# AgEAMAcCAQACAiZiMAcCAQACAhNNMAoCBQDpwJkpAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAHkeuWnOxhh3atnmAPdezsd6hy3A3O/4nRonSeMjVFXYysT6
# JEtJpiwgLuzn6LCsN7GPNJHCT+pw0DSCYiCa8vvbKSNPjkrhvIII3+2IopstErBg
# fxg4JMNMKHeA0nq+erPdp18Y7fUHti1CVwkgEYEnCznmGoZNrTtnJxVVRdXvpcBD
# 1hhsuCLDNh/BC/utHa9EQ9cdPgxJjzrsUWeaprvHt3REH38K5EnnrZlTSI/LJpqi
# rZiJmK8mvybnIY9g8cL6EkrP6SfBfzLtjECFWGEIXCe/nAb7i83zgDWNLtcRp5vI
# UHJbb66dj/X46C2sjm2lolC50s+VubcGsbDds+QxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAe4F0wIwspqdpwABAAAB7jAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCC3Nw4G02PObFeGgEIOfrlcbhIjjHkLAImu6uTS00TXWTCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIE9QdxSVhfq+Vdf+DPs+5EIkBz9o
# CS/OQflHkVRhfjAhMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAHuBdMCMLKanacAAQAAAe4wIgQg7EgOLj4PfSP5Q3eXE6Fbw4SJvUoS
# UtHmtOUMnbk66SAwDQYJKoZIhvcNAQELBQAEggIAnhMByo5KtDM5Cz+/ZxKP9krG
# m4hoV99VksJvIBlafBIoHwhqKFIAtE51H9ilz3FpEITgUpltBdx8WQ6qW0oNqOj2
# icjwO7krK92mANfO71MxXhL3hGNN4Rix7Y0kXuuI3JvlxDDkhWE2bEgySZSpsbfP
# ViCiWtWWLon/8Cbx2hNWiQ6OWEcHzqdZpGDG8OPflLzWsw6VErt9dpKu17XeInc6
# nJh9sqUF0aSyvEftfs6KGYAwuQnfbo5r3RQo9Gvmzzp8PCIW/4OcVcREQkH/BO0i
# Jkuc9C+IqGd5sEVi2hwtL/RTHtdwi+Y4K4Mtuj2ZjtOC/IfJoOalTVhbFVllH6+0
# D7N8bEi6uG1s3m9Zs/2YX+/kT7E600graskxl4fEnZSstOFHdsaBnR4JaqCXzSR5
# W99tW2FnecA+HI6S1ra1pzXuotuDG2cOkXyq6pxBvrMGrXAlosl4OUvlX4NY5w2g
# ERTWf6DofvB2JANUQY15xjbWiUm7GQteG620CjFZU5Q26gQLmaNGyd9G7ckqfMci
# cLSFUkRUDyk68p0WY/6+RD57DS6KAkQXOLrYGVJJLYkSLE7N4vDElpizI6+NCgrg
# BdlGivArCHMwbQQaKON3BtxqSN13hHLk3w3qBqP+b2c+/FUUeDfPQU+QXay+UZc2
# LfizqxLu1Xg30iRwYSk=
# SIG # End signature block
