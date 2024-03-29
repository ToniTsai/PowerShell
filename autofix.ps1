Function AutoFix-WebConfig([string] $rootDirectory)
{
    $files = Get-ChildItem -Path $rootDirectory -Filter web.config -Recurse

    return Scan-ConfigFiles($files)
}

Function AutoFix-AppConfig([string] $rootDirectory)
{
    $files = Get-ChildItem -Path $rootDirectory -Filter app.config -Recurse

    return Scan-ConfigFiles($files)
}

Function Scan-ConfigFiles([System.IO.FileInfo[]] $files)
{
    $modifiedfiles = @()

    foreach($file in $files)
    {
        $original = [xml] (Get-Content $file.FullName)
        $workingCopy = $original.Clone()

        if ($workingCopy.configuration.appSettings -ne $null){
            $sorted = $workingCopy.configuration.appSettings.add | sort { [string]$_.key }
            $lastChild = $sorted[-1]
            $sorted[0..($sorted.Length-2)] | foreach {$workingCopy.configuration.appSettings.InsertBefore($_, $lastChild)} | Out-Null
        }

        if ($workingCopy.configuration.runtime.assemblyBinding -ne $null){
            $sorted = $workingCopy.configuration.runtime.assemblyBinding.dependentAssembly | sort { [string]$_.assemblyIdentity.name }
            $lastChild = $sorted[-1]
            $sorted[0..($sorted.Length-2)] | foreach {$workingCopy.configuration.runtime.assemblyBinding.InsertBefore($_,$lastChild)} | Out-Null
        }

        $differencesCount = (Compare-Object -ReferenceObject (Select-Xml -Xml $original -XPath "//*") -DifferenceObject (Select-Xml -Xml $workingCopy -XPath "//*")).Length

        if ($differencesCount -ne 0)
        {
            $workingCopy.Save($file.FullName) | Out-Null
            $modifiedfiles += $file.FullName
        }
    }

    return $modifiedfiles
}

Function AutoFix-CsProj([string] $rootDirectory)
{
    $files = Get-ChildItem -Path $rootDirectory -Filter *.csproj -Recurse
    $modifiedfiles = @()

    foreach($file in $files)
    {
        $original = [xml] (Get-Content $file.FullName)
        $workingCopy = $original.Clone()

        foreach($itemGroup in $workingCopy.Project.ItemGroup){

            # Sort the reference elements
            if ($itemGroup.Reference -ne $null){

                $sorted = $itemGroup.Reference | sort { [string]$_.Include }

                $itemGroup.RemoveAll() | Out-Null
                foreach($item in $sorted){
                    $itemGroup.AppendChild($item) | Out-Null
                }
            }

            # Sort the compile elements
            if ($itemGroup.Compile -ne $null){

                $sorted = $itemGroup.Compile | sort { [string]$_.Include }

                $itemGroup.RemoveAll() | Out-Null
                foreach($item in $sorted){
                    $itemGroup.AppendChild($item) | Out-Null
                }
            }

            # Sort the project references elements
            if ($itemGroup.ProjectReference -ne $null){

                $sorted = $itemGroup.ProjectReference | sort { [string]$_.Include }

                $itemGroup.RemoveAll() | Out-Null
                foreach($item in $sorted){
                    $itemGroup.AppendChild($item) | Out-Null
                }
            }
        }

        $differencesCount = (Compare-Object -ReferenceObject (Select-Xml -Xml $original -XPath "//*") -DifferenceObject (Select-Xml -Xml $workingCopy -XPath "//*")).Length

        if ($differencesCount -ne 0)
        {
            $workingCopy.Save($file.FullName) | Out-Null
            $modifiedfiles += $file.FullName
        }
    }

    return $modifiedfiles
}

$rootDirectory = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "\..\..\"

$exitCode = 0;

$changedfiles = @()
$changedfiles += AutoFix-AppConfig($rootDirectory)
$changedfiles += AutoFix-CsProj($rootDirectory)
$changedfiles += AutoFix-WebConfig($rootDirectory)

if ($changedfiles.Count -gt 0)
{
    Write-Host "=== git hooks ==="
    Write-Host "The following files have been auto-formatted"
    Write-Host "to reduce the likelyhood of merge conflicts:"
    foreach($file in $changedfiles)
    {
        Write-Host $file
    }

    $exitCode = 1;
}

exit $exitcode