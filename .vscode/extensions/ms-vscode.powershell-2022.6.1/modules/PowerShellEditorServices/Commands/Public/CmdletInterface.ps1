# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.EXTERNALHELP ..\PowerShellEditorServices.Commands-help.xml
#>
function Register-EditorCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter(
            Mandatory=$true,
            ParameterSetName="Function")]
        [ValidateNotNullOrEmpty()]
        [string]$Function,

        [Parameter(
            Mandatory=$true,
            ParameterSetName="ScriptBlock")]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]$ScriptBlock,

        [switch]$SuppressOutput
    )

    Process
    {
        $commandArgs = @($Name, $DisplayName, $SuppressOutput.IsPresent)

        $editorCommand = if ($ScriptBlock -ne $null)
        {
            Write-Verbose "Registering command '$Name' which executes a ScriptBlock"
            [Microsoft.PowerShell.EditorServices.Extensions.EditorCommand, Microsoft.PowerShell.EditorServices]::new($Name, $DisplayName, $SuppressOutput, $ScriptBlock)
        }
        else
        {
            Write-Verbose "Registering command '$Name' which executes a function"
            [Microsoft.PowerShell.EditorServices.Extensions.EditorCommand, Microsoft.PowerShell.EditorServices]::new($Name, $DisplayName, $SuppressOutput, $Function)
        }

        if ($psEditor.RegisterCommand($editorCommand))
        {
            Write-Verbose "Registered new command '$Name'"
        }
        else
        {
            Write-Verbose "Updated existing command '$Name'"
        }
    }
}

<#
.EXTERNALHELP ..\PowerShellEditorServices.Commands-help.xml
#>
function Unregister-EditorCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Process
    {
        Write-Verbose "Unregistering command '$Name'"
        $psEditor.UnregisterCommand($Name);
    }
}

<#
.SYNOPSIS
    Creates new files and opens them in your editor window
.DESCRIPTION
    Creates new files and opens them in your editor window
.EXAMPLE
    PS > New-EditorFile './foo.ps1'
    Creates and opens a new foo.ps1 in your editor
.EXAMPLE
    PS > Get-Process | New-EditorFile proc.txt
    Creates and opens a new proc.txt in your editor with the contents of the call to Get-Process
.EXAMPLE
    PS > Get-Process | New-EditorFile proc.txt -Force
    Creates and opens a new proc.txt in your editor with the contents of the call to Get-Process. Overwrites the file if it already exists
.INPUTS
    Path
    an array of files you want to open in your editor
    Value
    The content you want in the new files
    Force
    Overwrites a file if it exists
#>
function New-EditorFile {
    [CmdletBinding()]
    param(
        [Parameter()]
        [String[]]
        [ValidateNotNullOrEmpty()]
        $Path,

        [Parameter(ValueFromPipeline=$true)]
        $Value,

        [Parameter()]
        [switch]
        $Force
    )

    begin {
        $valueList = @()
    }

    process {
        $valueList += $Value
    }

    end {
        # If editorContext is null, then we're in a Temp session and
        # this cmdlet won't work so return early.
        try {
            $editorContext = $psEditor.GetEditorContext()
        }
        catch {
            # If there's no editor, this throws an error. Create a new file, and grab the context here.
            # This feels really hacky way to do it, but not sure if there's another way to detect editor context...
            $psEditor.Workspace.NewFile()
            $editorContext = $psEditor.GetEditorContext()
        }

        if (!$editorContext) {
            return
        }

        if ($Path) {
            foreach ($fileName in $Path)
            {
                if (-not (Test-Path $fileName) -or $Force) {
                    New-Item -Path $fileName -ItemType File | Out-Null

                    if ($Path.Count -gt 1) {
                        $preview = $false
                    } else {
                        $preview = $true
                    }

                    # Resolve full path before passing to editor
                    if (!([System.IO.Path]::IsPathRooted($fileName))) {
                        $fileName = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($fileName)
                    }

                    $psEditor.Workspace.OpenFile($fileName, $preview)
                    $editorContext.CurrentFile.InsertText(($valueList | Out-String))
                } else {
                    $PSCmdlet.WriteError( (
                        New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @(
                            [System.IO.IOException]"The file '$fileName' already exists.",
                            'NewEditorFileIOError',
                            [System.Management.Automation.ErrorCategory]::WriteError,
                            $fileName) ) )
                }
            }
        } else {
            $psEditor.Workspace.NewFile()
            $editorContext.CurrentFile.InsertText(($valueList | Out-String))
        }
    }
}

function Open-EditorFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    begin {
        $Paths = @()
    }

    process {
        $Paths += $Path
    }

    end {
        if ($Paths.Count -gt 1) {
            $preview = $false
        } else {
            $preview = $true
        }

        Get-ChildItem $Paths -File | ForEach-Object {
            $psEditor.Workspace.OpenFile($_.FullName, $preview)
        }
    }
}
Set-Alias psedit Open-EditorFile -Scope Global

Export-ModuleMember -Function Open-EditorFile,New-EditorFile

# SIG # Begin signature block
# MIInnwYJKoZIhvcNAQcCoIInkDCCJ4wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCF4+bJLmOjlFOD
# xjFqt/VD2I3ChT7bjkO+EJTeOjP6rqCCDXYwggX0MIID3KADAgECAhMzAAACURR2
# zMWFg24LAAAAAAJRMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjEwOTAyMTgzMjU5WhcNMjIwOTAxMTgzMjU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDBIpXR3b1IYAMunV9ZYBVYsaA7S64mqacKy/OJUf0Lr/LW/tWlJDzJH9nFAhs0
# zzSdQQcLhShOSTUxtlwZD9dnfIcx4pZgu0VHkqQw2dVc8Ob21GBo5sVrXgEAQxZo
# rlEuAl20KpSIFLUBwoZFGFSQNSMcqPudXOw+Mhvn6rXYv/pjXIjgBntn6p1f+0+C
# 2NXuFrIwjJIJd0erGefwMg//VqUTcRaj6SiCXSY6kjO1J9P8oaRQBHIOFEfLlXQ3
# a1ATlM7evCUvg3iBprpL+j1JMAUVv+87NRApprPyV75U/FKLlO2ioDbb69e3S725
# XQLW+/nJM4ihVQ0BHadh74/lAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUMLgM7NX5EnpPfK5uU6FPvn2g/Ekw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzQ2NzU5NjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAIVJlff+Fp0ylEJhmvap
# NVv1bYLSWf58OqRRIDnXbHQ+FobsOwL83/ncPC3xl8ySR5uK/af4ZDy7DcDw0yEd
# mKbRLzHIfcztZVSrlsg0GKwZuaB2MEI1VizNCoZlN+HlFZa4DNm3J0LhTWrZjVR0
# M6V57cFW0GsV4NlqmtelT9JFEae7PomwgAV9xOScz8HzvbZeERcoSRp9eRsQwOw7
# 8XeCLeglqjUnz9gFM7RliCYP58Fgphtkht9LNEcErLOVW17m6/Dj75zg/IS+//6G
# FEK2oXnw5EIIWZraFHqSaee+NMgOw/R6bwB8qLv5ClOJEpGKA3XPJvS9YgOpF920
# Vu4Afqa5Rv5UJKrsxA7HOiuH4TwpkP3XQ801YLMp4LavXnvqNkX5lhFcITvb01GQ
# lcC5h+XfCv0L4hUum/QrFLavQXJ/vtirCnte5Bediqmjx3lswaTRbr/j+KX833A1
# l9NIJmdGFcVLXp1en3IWG/fjLIuP7BqPPaN7A1tzhWxL+xx9yw5vQiT1Yn14YGmw
# OzBYYLX0H9dKRLWMxMXGvo0PWEuXzYyrdDQExPf66Fq/EiRpZv2EYl2gbl9fxc3s
# qoIkyNlL1BCrvmzunkwt4cwvqWremUtqTJ2B53MbBHlf4RfvKz9NVuh5KHdr82AS
# MMjU4C8KNTqzgisqQdCy8unTMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGX8wghl7AgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAJRFHbMxYWDbgsAAAAAAlEwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIP8kciM4/ao4XJoTqx7480hl
# XytORZumwkDNvAD2msSHMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAfwYxO8AphV16wTmMo/Cu7NJSO0+53fwAWsU1bDvt4YbpZZUZOKSYkxFP
# 2FQWPdUgXv6RqGu8iS18UAM2nH9NBt5LHrfd4TSdxmFnlB++bcXqWbhgpAzSuzwZ
# Ez5LBRdGEu6hFF++4FzqFPg514tPBbQkxWMd0QwgsB19bMetz9+f7n+faf1R2VI8
# uj1Pzd3KCWNhZID+utEBnlU0hfNRFjaTSb0UGnhVyag44VX0itjIDOfBzqtxlhNc
# ZVWnxVo0CBI39wS9lKkE5MnSs8LrHoE4SeW/yoLtHjI2d3Nw2eV6nbuNLolydTUp
# NGex5DwGyw2SAJnG8h0uD/2mjrWh+6GCFwkwghcFBgorBgEEAYI3AwMBMYIW9TCC
# FvEGCSqGSIb3DQEHAqCCFuIwghbeAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFVBgsq
# hkiG9w0BCRABBKCCAUQEggFAMIIBPAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAae7QZ3PEFMJipRtDlIj+fAt4bz9WcBq5Q8+2/8/hSCwIGYoTw9kZH
# GBMyMDIyMDYxNDE2Mjg0MS4yNjhaMASAAgH0oIHUpIHRMIHOMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3Bl
# cmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046Rjc3
# Ri1FMzU2LTVCQUUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZp
# Y2WgghFcMIIHEDCCBPigAwIBAgITMwAAAaqlMZsLy7IIDgABAAABqjANBgkqhkiG
# 9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYw
# JAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMjAzMDIx
# ODUxMjZaFw0yMzA1MTExODUxMjZaMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVy
# dG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046Rjc3Ri1FMzU2LTVCQUUx
# JTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQCgT+xyudW1h3/hQ0ofTu2Mq0LZDTL3R8x4
# ms7znSPTzho8iSGK7NVjjJkgqd6P5r7Lj5xUj+XNHQngblKuruid9DPNWWjTj/2m
# 2a08GK2DfjeZ0razhnQrUQbpu+ocu069wGQ1AKy8L4bBpV4S5Q1NcIqGsTPgVcAj
# SOy5k2mCqo5ufIRILGLSiB5OfS8zpyOGnp2zywT/1WGIyOmuCiHLp9BGRKwLpLeT
# wv5ilGjqYVDBmJtD8X6WPQZBubD33MxciHwNdyy0UuLBoW1K3DOeBLxNhZVgUGia
# O36yluwlYyEyxF+BNpccEBvzLmftcA2IPTjhK0+Yfus3nI+u3np8MXlKGjhGyrYl
# MWiVGJ8kCsQlk5DXVkV0ykpiMcdLW7D+Yq1o6l70+rf83iSsNOTWPIT0+er1ttKt
# A2CtjbXjggw9FA+mTQBS1fOxjpJdHgal3E6BVXXicMDkxOmgOEamKDa9kFDwSFOi
# RIlBgbPXOKguZgR02OOlWkf6HWhQy3MUCODj5J+WpfyD7HfP62g5jHyopOusXDYd
# qjeMsrWDN7og3p1+anhXcd6XYuN6WABTf0tf91UTZPvxkVVFGFmAYw2UqsbJYnRP
# IbMQuyvKi35jaGkNmgLLtd4dX2kzEmSBFcaLM9W/ciHl5rTOjZa41d3rcEuyV2MB
# oRzHVWBC9QIDAQABo4IBNjCCATIwHQYDVR0OBBYEFD+aFLxThy7YX3dFs94RrZ0F
# RqSeMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYw
# VKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jv
# c29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcB
# AQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSku
# Y3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcN
# AQELBQADggIBAN8MgE2QRRAaIK3MB7OMyO6l9stI2ygiOmYnhgCEfekYjK42b1ht
# /WDwPxS9r4RkgrTu3mt4gZcIYU8iRD3sS7oE+IweFtK5XTiz+WxHNM8MbPTbUxUv
# FJds2ye48+VsUp4Uh7H2lRVKe0ugdmtW4ypliKP0r3d1tVd5nCGM4W6SyFFZT9wm
# 0yRBPnAt4V/iYIJ0mERE8qPpiOx8/yjFhWkVgVGCOINAa8IldpWKisnpIzaeq4+2
# /JejoW4F/yT9G8zcb+oqNGOIjZSM8/z3SIfxNqY96Vz4kCT0ZRJDJLEXnBPFZxcq
# oUeH2/xenOcsGOPphKbISAINmFF7MBaqmyvRb/lPGGHJWD74Sv8EWbPv+WriuBTP
# kE48sI9Aua5q/DM4qplBoALsGUGMh0QqKZ1XZWjv8cUmQn2mUe8OwdzgRJfI/laK
# H7NSn6vQJpkAFmTo7eA5zZOTZ8U4T740FbjlP8vh0xK8Kg/8CkQpdACd1D0yfDz2
# Kfo2xF5CpqBYVOCRnq+Xmo9tp19fabozWSqqmq7eMi4zVDpKlo1ZOCh6XWERnCTF
# V5CpEAIpY1J/XB0cDbj8/07u2Jn4EV1jeB7wnE9ptUAA4pzmT7Dub+Y/2xMcNFph
# a1tgrQxAKZwpZogCnIRa9MUihORE/gMrmy2qXoxDa/b7e0Fzaumj9V1nMIIHcTCC
# BVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMw
# MTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3mi
# y9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+
# Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3
# oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+
# tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0
# hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLN
# ueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZ
# nkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n
# 6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC
# 4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vc
# G9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtF
# tvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEE
# BQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNV
# HQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3
# TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkG
# CSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8E
# BTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRP
# ME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEww
# SgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCd
# VX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQ
# dTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnu
# e99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYo
# VSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlC
# GVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZ
# lvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/
# ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtq
# RRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+
# y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgk
# NWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqK
# Oghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAs8wggI4AgEBMIH8oYHU
# pIHRMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYD
# VQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMd
# VGhhbGVzIFRTUyBFU046Rjc3Ri1FMzU2LTVCQUUxJTAjBgNVBAMTHE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAOBtJtCeHgJZY3D/
# 47zr/f6Zv+vGoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# DQYJKoZIhvcNAQEFBQACBQDmUwb5MCIYDzIwMjIwNjE0MTcwOTEzWhgPMjAyMjA2
# MTUxNzA5MTNaMHQwOgYKKwYBBAGEWQoEATEsMCowCgIFAOZTBvkCAQAwBwIBAAIC
# F4kwBwIBAAICEVMwCgIFAOZUWHkCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOB
# gQDi4n2Gs2PTWxJuYSc6wvUb4Rp6nAopzMxaL+Qt/swWNVp7hHlw8rvlL2y1312Z
# uvfKEQX7JKlCiAbepFup0nS6M+pRVWnzHOBzpHjp6O4YThjiN4Tblax3MLyr1Jqy
# kS0z/uoDfnPDlMSk/2mbAusxAZhXCRbruOcQRG4MYKiqxzGCBA0wggQJAgEBMIGT
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABqqUxmwvLsggOAAEA
# AAGqMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQ
# AQQwLwYJKoZIhvcNAQkEMSIEIAscWe5RiFeUJiNPyy8JvbzgGKOnqVjYriZef9lI
# OTlqMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgVrUCQxxavBHgc9017oAq
# kYUiPyQmWwE2BCMExvGzHsAwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAAaqlMZsLy7IIDgABAAABqjAiBCDhVCWUHN35NaBc7mbJWuBR
# aMNpXNjYgd3N66ytgDUPuTANBgkqhkiG9w0BAQsFAASCAgBXvmY6NFZ9jcMQLDXp
# XR7voKDH0kHGH9XMufptlS6MYNTi3JvCGgDDVVoAR6Oc+SzRiYR1sXmYgbCmeKQU
# CNoRmeTy07MaC7k13RrvWRAuBj1sSvv/sklxCOogcwxykCOCxKTvZViRaiTfK7nv
# lruRhi9Wl6cvYAmWH0dfKuVgsjfX3GhnBQ/pmWpFpxDFiX62We5lLAfqwrdN4UgM
# QLzGyyU21OgnEoKyYmSQwW7HcY9PeKzW4hrJE4BPatDM2RNkjjMXZOMRNpJdY8+I
# /hn3ybQi3jn65Hl5Mg0XfFopvQRAlkWb+/63pmlbAP4OW81Cg8Ybr+Yyky/U4X+p
# TwXdS2HQ3O7LPjuJFBApcGQMD3ROnYs0X4iha5UqhaTBS7WpkZwkCxRRu18F4ViF
# z6DCQMJoLFTIzhBFV4PuoHGEYaxA2vGJgjPhJKBs3Q3XHGG5IVAasUwyB0H1dF4T
# v/bYc1D1HMHm+jCYC8NsclmJbtQSRYQYEgiZ09b5CJKJ13lWImu7quunprDqtFJq
# 06k8OJ9TvuxRCKK7zjZHLGHvkUjkrA9fDEI4hXxonlG14JTigeueFSO3ocwbWVzE
# C5VZsYtg4675bpF0wwnseI5khe7m4Ydmj7ZzXu9xb/kjoNR+QJofF4vUeXow+SDD
# vyeQGzU8gmgQ9v6pcy/g2tm3Aw==
# SIG # End signature block
