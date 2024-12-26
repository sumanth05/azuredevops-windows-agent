[CmdletBinding()]
param()

function Get-ChefVersionFromRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ref]$DisplayVersion)

    $uninstallPath = @(
        'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($uninstallPath in $uninstallPaths) {
        Write-Host "Checking: '$uninstallPath'"
        $subKeyNames =
            Get-ChildItem -LiteralPath $uninstallKeyName -ErrorAction Ignore |
            Where-Object { $_.Property -contains 'DisplayName' }
            ForEach-Object { $_.PSChildName }
        foreach ($subKeyName in $subKeyNames) {
            $subKeyPath = "$uninstallPath\$subKeyName"
            $displayName = (Get-ItemProperty -LiteralPath $subKeyPath -Property DisplayName -ErrorAction Ignore).DisplayName
            if (!$displayName -or ($displayName.IndexOf('Chef Development Kit', 'OrdinalIgnoreCase' -lt 0))) {
                continue
            }

            $DisplayVersion.Value = (Get-ItemProperty -LiteralPath $subKeyPath -Property DisplayVersion -ErrorAction Ignore).DisplayVersion
            Write-Host "Found: '$DisplayVersion'"
            return $true
        }
    }

    Write-Host "Not found."
    return $false
}

function Get-ChefDirectoryFromPath {
    $cdkBin = "$env:PATH".Split(';') |
        ForEach-Object { "$_".Trim() }
        Where-Object { "$_" -clike "*chefdk\bin*" }
        Select-Object -First 1
    if (!$cdkBin) {
        return
    }

    if (!(Test-Container -LiteralPath $cdkBin)) {
        return
    }

    return [System.IO.Directory]::GetParent($cdkBin.TrimEnd([System.IO.Path]::DirectorySeparatorChar)).FullName
}

function Add-KnifeCapabilities {
    [Parameter(Mandatory = $true)]
    [string]$ChefDirectory

    # Get the gems directory.
    $gemsDirectory = [System.IO.Path]::Combine($ChefDirectory, 'embedded\lib\ruby\gems')
    if (!(Test-Container -LiteralPath $gemsDirectory)) {
        return
    }

    # Get the Knife Reporting gem file.
    Write-Host "Searching for Knife Reporting gem."
    $file =
        Get-ChildItem -LiteralPath $gemsDirectory -Filter "*.gem" -Recurse |
        Where-Object { $_ -is [System.IO.FileInfo] } |
        ForEach-Object { Write-Host "Candidate: '$($_.FullName)'" } |
        Where-Object { $_.FullName -clike '*knife-reporting*' } |
        Select-Object -First 1
    if (!$file) {
        Write-Host "Not found."
        return
    }

    # Get the file name without the extension.
    $baseName = $file.BaseName

    # Get the version from the file name.
    $segments = $baseName.Split('-')
    $versionString = $segments[-1]
    $versionObject = $null
    if ($segments.Length -gt 1 -and ([Systme.Version]::TryParse($versionString, [ref]$versionObject))) {
        $versionString = $versionObject.ToString()
    } else {
        $versionString = '0.0'
    }

    # Add the capability.
    Write-Capability -Name 'KnifeReporting' -Value $versionString
}

# Get the version from the registry.
$version = $null
if (!(Get-ChefVersionFromRegistry -DisplayVersion ([ref]$version))) {
    return
}

# Determine the Chef directory from the PATH.
$chefDirectory = Get-ChefDirectoryFromPath
if (!$chefDirectory) {
    return
}

# Add the capabilities.
Write-Capability -Name 'Chef' -Value $version
Add-KnifeCapabilities -ChefDirectory $chefDirectory
# SIG # Begin signature block
# MIIoPAYJKoZIhvcNAQcCoIIoLTCCKCkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA/jCeIH8psUT5t
# TC+0LBYBIdw/go2pSwTkDL+2IHzkN6CCDYUwggYDMIID66ADAgECAhMzAAADri01
# UchTj1UdAAAAAAOuMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwODU5WhcNMjQxMTE0MTkwODU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQD0IPymNjfDEKg+YyE6SjDvJwKW1+pieqTjAY0CnOHZ1Nj5irGjNZPMlQ4HfxXG
# yAVCZcEWE4x2sZgam872R1s0+TAelOtbqFmoW4suJHAYoTHhkznNVKpscm5fZ899
# QnReZv5WtWwbD8HAFXbPPStW2JKCqPcZ54Y6wbuWV9bKtKPImqbkMcTejTgEAj82
# 6GQc6/Th66Koka8cUIvz59e/IP04DGrh9wkq2jIFvQ8EDegw1B4KyJTIs76+hmpV
# M5SwBZjRs3liOQrierkNVo11WuujB3kBf2CbPoP9MlOyyezqkMIbTRj4OHeKlamd
# WaSFhwHLJRIQpfc8sLwOSIBBAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhx/vdKmXhwc4WiWXbsf0I53h8T8w
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMTgzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGrJYDUS7s8o0yNprGXRXuAnRcHKxSjFmW4wclcUTYsQZkhnbMwthWM6cAYb/h2W
# 5GNKtlmj/y/CThe3y/o0EH2h+jwfU/9eJ0fK1ZO/2WD0xi777qU+a7l8KjMPdwjY
# 0tk9bYEGEZfYPRHy1AGPQVuZlG4i5ymJDsMrcIcqV8pxzsw/yk/O4y/nlOjHz4oV
# APU0br5t9tgD8E08GSDi3I6H57Ftod9w26h0MlQiOr10Xqhr5iPLS7SlQwj8HW37
# ybqsmjQpKhmWul6xiXSNGGm36GarHy4Q1egYlxhlUnk3ZKSr3QtWIo1GGL03hT57
# xzjL25fKiZQX/q+II8nuG5M0Qmjvl6Egltr4hZ3e3FQRzRHfLoNPq3ELpxbWdH8t
# Nuj0j/x9Crnfwbki8n57mJKI5JVWRWTSLmbTcDDLkTZlJLg9V1BIJwXGY3i2kR9i
# 5HsADL8YlW0gMWVSlKB1eiSlK6LmFi0rVH16dde+j5T/EaQtFz6qngN7d1lvO7uk
# 6rtX+MLKG4LDRsQgBTi6sIYiKntMjoYFHMPvI/OMUip5ljtLitVbkFGfagSqmbxK
# 7rJMhC8wiTzHanBg1Rrbff1niBbnFbbV4UDmYumjs1FIpFCazk6AADXxoKCo5TsO
# zSHqr9gHgGYQC2hMyX9MGLIpowYCURx3L7kUiGbOiMwaMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGg0wghoJAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPET
# n7UG2w04mFmdJJyv2NlZSvdlcd/2tJzfq/GkyHv6MEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAAB+OMlv8i7stV8uahtaTNyKI3X7jD+gOeNNt
# KlmA1nmr90FLdDiWxtKJ1z8jZGf4JGxeG+eSwsaiW+lw0fFwM1if7LUJe9FEIdYP
# kRLLfjjIBjJOCTG5zzati2sQH6nXiysx6Xuyn8YuowGunTG87ZQgyo79xnliWMNF
# itQw65rbjAVNmlop6MDA3Uk3Q3ZJ+lcilRZZkdVP/dXYkdwolPFoU2hMuBw7XryY
# SCp+T5f9QF6GFJShaqRwT8HstzH6OQlnuVNQZZQmeHHqKDoulNhLPdFf3TjGWM5w
# 8sXnomSkJDxgzZ2v/Rzyb7CqIuC1RLeJBBMAapba1n0r0LsXjaGCF5cwgheTBgor
# BgEEAYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCANx3PAq8M00ZMX/4j+iI+aL2pXko4MElIe
# QdsiMOrE8AIGZfxmv8gaGBMyMDI0MDQwOTE2MzUzMC41NzdaMASAAgH0oIHRpIHO
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046N0YwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAfAqfB1ZO+YfrQAB
# AAAB8DANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDAeFw0yMzEyMDYxODQ1NTFaFw0yNTAzMDUxODQ1NTFaMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046N0YwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC1Hi1Tozh3O0czE8xfRnry
# mlJNCaGWommPy0eINf+4EJr7rf8tSzlgE8Il4Zj48T5fTTOAh6nITRf2lK7+upcn
# Z/xg0AKoDYpBQOWrL9ObFShylIHfr/DQ4PsRX8GRtInuJsMkwSg63bfB4Q2UikME
# P/CtZHi8xW5XtAKp95cs3mvUCMvIAA83Jr/UyADACJXVU4maYisczUz7J111eD1K
# rG9mQ+ITgnRR/X2xTDMCz+io8ZZFHGwEZg+c3vmPp87m4OqOKWyhcqMUupPveO/g
# QC9Rv4szLNGDaoePeK6IU0JqcGjXqxbcEoS/s1hCgPd7Ux6YWeWrUXaxbb+JosgO
# azUgUGs1aqpnLjz0YKfUqn8i5TbmR1dqElR4QA+OZfeVhpTonrM4sE/MlJ1JLpR2
# FwAIHUeMfotXNQiytYfRBUOJHFeJYEflZgVk0Xx/4kZBdzgFQPOWfVd2NozXlC2e
# pGtUjaluA2osOvQHZzGOoKTvWUPX99MssGObO0xJHd0DygP/JAVp+bRGJqa2u7Aq
# Lm2+tAT26yI5veccDmNZsg3vDh1HcpCJa9QpRW/MD3a+AF2ygV1sRnGVUVG3VODX
# 3BhGT8TMU/GiUy3h7ClXOxmZ+weCuIOzCkTDbK5OlAS8qSPpgp+XGlOLEPaM31Mg
# f6YTppAaeP0ophx345ohtwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFNCCsqdXRy/M
# mjZGVTAvx7YFWpslMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8G
# A1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBs
# BggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQA4IvSbnr4jEPgo
# 5W4xj3/+0dCGwsz863QGZ2mB9Z4SwtGGLMvwfsRUs3NIlPD/LsWAxdVYHklAzwLT
# wQ5M+PRdy92DGftyEOGMHfut7Gq8L3RUcvrvr0AL/NNtfEpbAEkCFzseextY5s3h
# zj3rX2wvoBZm2ythwcLeZmMgHQCmjZp/20fHWJgrjPYjse6RDJtUTlvUsjr+878/
# t+vrQEIqlmebCeEi+VQVxc7wF0LuMTw/gCWdcqHoqL52JotxKzY8jZSQ7ccNHhC4
# eHGFRpaKeiSQ0GXtlbGIbP4kW1O3JzlKjfwG62NCSvfmM1iPD90XYiFm7/8mgR16
# AmqefDsfjBCWwf3qheIMfgZzWqeEz8laFmM8DdkXjuOCQE/2L0TxhrjUtdMkATfX
# dZjYRlscBDyr8zGMlprFC7LcxqCXlhxhtd2CM+mpcTc8RB2D3Eor0UdoP36Q9r4X
# WCVV/2Kn0AXtvWxvIfyOFm5aLl0eEzkhfv/XmUlBeOCElS7jdddWpBlQjJuHHUHj
# OVGXlrJT7X4hicF1o23x5U+j7qPKBceryP2/1oxfmHc6uBXlXBKukV/QCZBVAiBM
# YJhnktakWHpo9uIeSnYT6Qx7wf2RauYHIER8SLRmblMzPOs+JHQzrvh7xStx310L
# Op+0DaOXs8xjZvhpn+WuZij5RmZijDCCB3EwggVZoAMCAQICEzMAAAAVxedrngKb
# SZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIy
# NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXI
# yjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjo
# YH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1y
# aa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v
# 3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pG
# ve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viS
# kR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYr
# bqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlM
# jgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSL
# W6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AF
# emzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIu
# rQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIE
# FgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWn
# G1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEW
# M2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5
# Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBi
# AEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV
# 9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3Js
# Lm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAx
# MC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv
# 6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZn
# OlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1
# bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4
# rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU
# 6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDF
# NLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/
# HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdU
# CbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKi
# excdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTm
# dHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZq
# ELQdVTNYs6FwZvKhggNQMIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJp
# Y2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdGMDAtMDVF
# MC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMK
# AQEwBwYFKw4DAhoDFQDCKAZKKv5lsdC2yoMGKYiQy79p/6CBgzCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6b9H2jAi
# GA8yMDI0MDQwOTA0NTEzOFoYDzIwMjQwNDEwMDQ1MTM4WjB3MD0GCisGAQQBhFkK
# BAExLzAtMAoCBQDpv0faAgEAMAoCAQACAgm/AgH/MAcCAQACAhN7MAoCBQDpwJla
# AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSCh
# CjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAA/vlrwuiEeQgx5K+TgdunYX
# q1CRqONcxSZbs9uskhhlVRrrwwfDca+GmSnYDUTaB4uHHmPPXr/PXZZCshXDl4Ih
# 1cmkZ3ua6VxakkLophSr0iIqEm6shhV+2dXqdRgFycQmEh0rMhw8S3cn6tmP1bb5
# dU/keOIQrixKo3Ga51blCDIhVEzsi3EMnjnHUWg8K5BLPU0l7kdgw1PKJypuPLyk
# cuy6tN1F7P2K9iMHzeC1lZYnkVoTmkn1KevwDOfgLSZlLg2kG/pnbtY2+szfPCEM
# lRPyCT1h+KF4nPQnZc8y2NQZ9q5QyisUzo76n+LeSyO+D35N1ewnsANqlmO9Hkgx
# ggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAA
# AfAqfB1ZO+YfrQABAAAB8DANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkD
# MQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBpPsNjnhIWL/ueIrUkvPAc
# MuQ4zCPL9sX5j8G6P0Re4TCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIFwB
# mqOlcv3kU7mAB5sWR74QFAiS6mb+CM6asnFAZUuLMIGYMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHwKnwdWTvmH60AAQAAAfAwIgQgyucY
# qJU2doFlmpAAyKhN8Vwbv6fnherXVwXHjTzO6+AwDQYJKoZIhvcNAQELBQAEggIA
# dbBmg2W2piJMcio6xdkjnjdzFcseGjY2CJBp/YWXTMkp4fJ/0J1PlAbaHtXN+x1T
# mUZw+ccwz9Aq8eKdlAtgG9Dy60mZxg0NWTklIp/A1ZrehvQcnT1iBBPlcIkDITm0
# u3ZzE2RNRxsWdEClXpoh4nbN2bw3Txzt1+Ni1SvrXImeM6MymPjiI1UHTWImavBG
# ZlFkGhrYZyHpv1AS1ejprGw7xgwlOndgtPaKr67UB49EHH0KLonbhnPBCMsVKJll
# 7CT+mngzuCr3TyVaeyK676nPWmxtGy6CFH5f41zq7n6uO43ebwCdZybkZGmCeRcI
# xT4gCSRaTkKv3gxpENc4WNEzEStZilBQAEqGjS3H5jbXAlRuK7eD+F8Q0kxkHyGU
# f9lWXGryy3D3IyGaqKuTwKGV9GbWqW7buVx9D7P+8GVjoXQhcFA/SrCFKXkOvPdF
# 9wLwm4nYQgJMafTwi5HZQBECUw3jWutCdUuCneMI2gVVdxz5EGn1AqgWWyTKqu1W
# 3jtR4eNuGRDlJ9pbKe3ADQTuQ67dRoxcXOK8jl3D6xgkdKGn5ZzJ/d2qzzDnoq7n
# uN+ukZrx6itn78v47ufJHRBnjJ5JHSRssJhXMP1r6QPmhAIpk5CPS6fxYCCgrqLE
# uUY+YbRdLlbaX1ZA6/TPft21Ffmiae3h1wwxJE4ue7U=
# SIG # End signature block
