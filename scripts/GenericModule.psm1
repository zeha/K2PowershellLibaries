Function Update-WebConfig()
{
    Param([string]$webConfigPath=".\IIS\K2CustomService\web.config", [string]$K2Host="Dev-K2server", [string]$K2HostPort="5555", [string]$K2WorkflowClientPort="5252", [string]$sqlInstance="alnldk201")
     
     #Set the Connection String and the path to web.config (or any config file for that matter)
    $currentDate = (get-date).tostring("yyyyMMddThhmmss") 
    $backup = $webConfigPath + "_$currentDate"

    # Get the content of the config file and cast it to XML and save a backup copy labeled .bak followed by the date
    $xml = [xml](get-content $webConfigPath)

      
    #$xml.Load($webConfigPath)

    #save a backup copy
    $xml.Save($backup)

    foreach($n in $xml.selectnodes("/configuration/appSettings/add"))
    {
        switch($n.key)
        {
            "K2HostServer" { $n.value =  $K2Host}
            "K2ConnectionString" { $n.value =  "Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$K2Host;Port=$K2HostPort"}
            "SQLConnectionString" { $n.value =  "Data Source=$sqlInstance;Initial Catalog=K2ProcessData;Integrated Security=SSPI;"}
            "K2WorkflowClientConnectionString" { $n.value =  "Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$K2Host;Port=$K2WorkflowClientPort"}
            
        } 
    }
     
    # Save it
    $xml.Save($webConfigPath)
}

Function Edit-NodeInXML()
{
<#
   .Synopsis
    This function replaces the content of all nodes in an xml file
   .Description
    This function replaces the content of all nodes in an xml file.  It can save to the same file it read from or to another
    It screws up the formatting royally, but you can live with that VS Edit - Advanced - Format Document
   .Example
        
        $xmlContent="<Parent><VeryBasic>rubbish</VeryBasic></Parent>"
        $ExpectedXmlContent="<Parent><VeryBasic>goodStuff</VeryBasic></Parent>"
        $xmlPath=".\funkyNewXML.xml"
        Set-Content $xmlPath $xmlContent
        Edit-NodeInXML $xmlPath "veryBasic" "goodStuff" $xmlPath
   .Parameter xmlTemplatePath
        The full path to the xml to change
   .Parameter $nodeName
        The node that needs to be changed
   .Parameter newValue
        The value the node needs to be changed to
   .Parameter xmlNewPath
        The new path. It can be the same as xmlTemplatePath
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
   #>
   Param([string]$xmlTemplatePath, 
            [string]$nodeName,
            [string]$newValue,
            [string]$xmlNewPath)


    write-debug "...replacing value of $nodeName nodes with $newValue in $xmlTemplatePath and saving to $xmlNewPath"
    
    $replaceRegex="<$nodeName>(.*)</$nodeName>"
    $replaceValue="<$nodeName>$newValue</$nodeName>"
    $NewFile = (Get-Content "$xmlTemplatePath") -join "" | foreach{$_ -replace $replaceRegex,$replaceValue};
    Set-Content "$xmlNewPath" $Newfile;
}

Function Get-EnvironmentFromUser()
{
<#
   .Synopsis
    This function prompts for an enviroment based on values in an XML file
   .Description
    This function prompts for an enviroment based on values in an XML file. The XML file must contain a set of tags
    under an <Environments> tag at any level
    <CanBeAnySetOfTags>
        <Environments>
            <DevelopmentVM>
              <K2Host>DLX</K2Host>
              <CouldBeAnyThingHere>5555</CouldBeAnyThingHere>
            </DevelopmentVM>
        </Environments>
    It simply reads all the tags 1 level directly under <Environments> and prompts the user to select which one they want
   .Example
        
        $xml = [xml](get-content $DeploymentFile)
        "Environment not passed in, ask the user"
        $Environment =Get-EnvironmentFromUser $xml
    
        $K2SERVER= $xml.environments.$Environment.K2Host
   .Parameter xml
        an xml variable that must have an <Environments> tag. It is required
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
   #>
   Param([xml]$xml)
    $options =@()
    $OptionNames =@()
    $i=0
    $title="Choose Environment"
    $message="Please select an environment"
    @($xml.SelectSingleNode("//Environments").ChildNodes) | ForEach-Object {

        $OptionName = $_.Name
        $optionNames = $optionNames += $OptionName
        $obj = New-Object System.Management.Automation.Host.ChoiceDescription "&$i. $OptionName", ""
        $options = $options += $obj
        $i++
    }
    $PromptOptions = [System.Management.Automation.Host.ChoiceDescription[]]($options)

    $EnvironmentChoice = $host.ui.PromptForChoice($title, $message, $PromptOptions, 0) 
    #$EnvironmentChoice
    $Environment =$OptionNames[$EnvironmentChoice]
    $Environment 
}

Function Get-EnvironmentSettingFromXML
{
Param(

	[parameter(Mandatory=$true)]          
    [ValidateNotNullOrEmpty()]     
	[string]$ManifestFile,
	
	[parameter(Mandatory=$true)]          
    [ValidateNotNullOrEmpty()]     
	[string]$Setting,
	
	[parameter(Mandatory=$true)]          
    [ValidateNotNullOrEmpty()]     
	[string]$Environment,
	
	[parameter(Mandatory=$true)]          
    [ValidateNotNullOrEmpty()]     
	[string]$ParentNode
	
	)

	If (test-path $ManifestFile) 
	{

		$xml = [xml](get-content $ManifestFile)
		write-verbose "deployment file found"
		$xml.$ParentNode.Environments.$Environment.$Setting
	}
	else
	{
		Throw "file not found : $ManifestFile"
	}
}

Function Get-Architecture()
{
<#
   .Synopsis
    This function detects how many bits the local machine has
   .Description
    This function detects how many bits the local machine has. It returns either 64 or 32
   .Example
        $arch=(Get-Architecture)
        If($arch -eq 64)
        {...
   .Parameter $CurrentProcess
        Not required. This is a standard powershell parameter
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>
param([switch]$CurrentProcess)

    if ($CurrentProcess.ispresent) 
    {
        $me=[diagnostics.process]::GetCurrentProcess()
        if ($me.path -match '\\syswow64\\') {
            32
        }
        else {
            64
        }
    }
    else 
    {
        $os=Get-WMIObject win32_operatingsystem
        if ($os.OSArchitecture -eq "64-bit") {
            64
        }
        else {
            32
        }
    }   
}

Function Test-Service()
{# PowerShell function to check a service's status
Param($srvName = "K2 blackpearl Server")
    $servicePrior = Get-Service $srvName
    $servicePrior.status
}

function Publish-VisualStudioSolution            
{            
    param            
    (            
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [String] $SourceCodePath = "C:\SourceCode\Development\",            
            
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [String] $SolutionFile,            
                    
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [String] $Configuration = "Debug",            
                    
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [Boolean] $AutoLaunchBuildLog = $false,            
            
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [Switch] $MsBuildHelp,            
                    
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [Switch] $CleanFirst,            
                    
        [ValidateNotNullOrEmpty()]             
        [string] $BuildLogFile,            
               
	[ValidateNotNullOrEmpty()]                  
        [string] $BuildLogOutputPath = $env:userprofile + "\Desktop\"            
    )            
                
    process            
    {            
        # Local Variables            
        $MsBuild = "$Global_FrameworkPath\MSBuild.exe";            
                
        # Caller requested MsBuild Help?            
        if($MsBuildHelp)            
        {            
                $BuildArgs = @{            
                    FilePath = $MsBuild            
                    ArgumentList = "/help"            
                    Wait = $true            
                    RedirectStandardOutput = "C:\MsBuildHelp.txt"            
                }            
            
                # Get the help info and show            
                Start-Process @BuildArgs            
                Start-Process -verb Open "C:\MsBuildHelp.txt";            
        }            
        else            
        {            
            # Local Variables            
            $SlnFilePath = $SourceCodePath + $SolutionFile;            
            $SlnFileParts = $SolutionFile.Split("\");            
            $SlnFileName = $SlnFileParts[$SlnFileParts.Length - 1];            
            $BuildLog = $BuildLogOutputPath + $BuildLogFile            
            $bOk = $true;            
                        
                      
                # Clear first?            
                if($CleanFirst)            
                {            
                    # Display Progress            
                    Write-Progress -Id 20275 -Activity $SlnFileName  -Status "Cleaning..." -PercentComplete 10;            
                            
                    $BuildArgs = @{            
                        FilePath = $MsBuild            
                        ArgumentList = $SlnFilePath, "/t:clean", ("/p:Configuration=" + $Configuration), "/v:minimal"            
                        RedirectStandardOutput = $BuildLog            
                        Wait = $true            
                        #WindowStyle = "Hidden"            
                    }   
					write-debug "enumerating the hash table that will be used as parameters to build the project"
					
					###$buildArgs.getenumerator() | write-debug { -messgae "$($_.name)" }
            
                    # Start the build            
                    Start-Process @BuildArgs #| Out-String -stream -width 1024 > $DebugBuildLogFile             
                                
                    # Display Progress            
                    Write-Progress -Id 20275 -Activity $SlnFileName  -Status "Done cleaning." -PercentComplete 50;            
                }            
            
                # Display Progress            
                Write-Progress -Id 20275 -Activity $SlnFileName  -Status "Building..." -PercentComplete 60;            
                            
                # Prepare the Args for the actual build            
                $BuildArgs = @{            
                    FilePath = $MsBuild            
                    ArgumentList = $SlnFilePath, "/t:rebuild", ("/p:Configuration=" + $Configuration), "/v:minimal"            
                    RedirectStandardOutput = $BuildLog            
                    Wait = $true            
                    #WindowStyle = "Hidden"            
                }            
            
                # Start the build            
                Start-Process @BuildArgs #| Out-String -stream -width 1024 > $DebugBuildLogFile             
                            
                # Display Progress            
                Write-Progress -Id 20275 -Activity $SlnFileName  -Status "Done building." -PercentComplete 100;            
                        
                
            # All good so far?            
            if($bOk)            
            {            
                #Show projects which where built in the solution            
                #Select-String -Path $BuildLog -Pattern "Done building project" -SimpleMatch            
                            
                # Show if build succeeded or failed...            
                $successes = Select-String -Path $BuildLog -Pattern "Build succeeded." -SimpleMatch            
                $failures = Select-String -Path $BuildLog -Pattern "Build failed." -SimpleMatch            
                            
                if($failures -ne $null)            
                {            
                    Write-Warning ($SlnFileName + ": A build failure occured. Please check the build log $BuildLog for details.");            
                }            
                            
                # Show the build log...            
                if($AutoLaunchBuildLog)            
                {            
                    Start-Process -verb "Open" $BuildLog;            
                }            
            }            
        }            
    }            
                
    <#
        .SYNOPSIS
        Executes the v2.0.50727\MSBuild.exe tool against the specified Visual Studio solution file.
        
        .Description
        
        .PARAMETER SourceCodePath
        The source code root directory. $SolutionFile can be relative to this directory. 
        
        .PARAMETER SolutionFile
        The relative path and filename of the Visual Studio solution file.
        
        .PARAMETER Configuration
        The project configuration to build within the solution file. Default is "Debug".
        
        .PARAMETER AutoLaunchBuildLog
        If true, the build log will be launched into the default viewer. Default is false.
        
        .PARAMETER MsBuildHelp
        If set, this function will run MsBuild requesting the help listing.
        
        .PARAMETER CleanFirst
        If set, this switch will cause the function to first run MsBuild as a "clean" operation, before executing the build.
        
        .PARAMETER BuildLogFile
        The name of the file which will contain the build log after the build completes.
        
        .PARAMETER BuildLogOutputPath
        The full path to the output folder where build log files will be placed. Defaults to the current user's desktop.
        
        .EXAMPLE
        
        .LINK
        http://stackoverflow.com/questions/2560652/why-does-powershell-fail-to-build-my-net-solutions-file-is-being-used-by-anot
        http://geekswithblogs.net/dwdii
        
        .NOTES
        Name:   Publish-VisualStudioSolution
        Author: Daniel Dittenhafer
    #>                
}

Function Add-GlobalVariables
{
   [CmdletBinding()]
   Param($doesNothing="")
   
   
    if("${Env:ProgramFiles(x86)}" -eq "")
    {
        write-debug "ProgramFiles(x86) not valid, using ProgramFiles"
        $ProgFiles="${Env:ProgramFiles}"
    }
    else
    {
        write-debug "ProgramFiles(x86) valid, using ProgramFiles(x86)"
        $ProgFiles="${Env:ProgramFiles(x86)}"
    }

   
	$arch=(Get-Architecture)
    If($arch -eq 64)
    {
        write-debug "64 bit Architecture"
        $64="64"
        $ProgFiles="${Env:ProgramFiles}"
        write-debug "64 bit so back to ProgramFiles"
        
    }
    elseIf($arch -eq 32)
    {
        write-debug "32 bit Architecture"
        
        $64=""
    }
    else
    {
        Throw "cannot determine Architecture"
    }

		if(Test-Path variable:global:Global_MsbuildPath)
    	{

            $Global_MsbuildPath="$ProgFiles\MSBuild\" 
            write-debug "Global_msbuildpath exists: $Global_MsbuildPath"
        }
        else
        {
            New-Variable -Name Global_MsbuildPath -Value "${Env:ProgramFiles}\MSBuild\" -Scope "Global" -option ReadOnly
            write-debug "Global_msbuildpath did not exist, so created it: $Global_MsbuildPath "
        }

    if(Test-Path variable:global:Global_FrameworkPath)
	{
        $Global_FrameworkPath="$env:SystemRoot\Microsoft.NET\Framework$64\v4.0.30319" 
        write-debug "Global_FrameworkPath exists: $Global_FrameworkPath"
    }
    else
    {
		New-Variable -Name Global_FrameworkPath -Value "$env:SystemRoot\Microsoft.NET\Framework$64\v4.0.30319" -Scope "Global" -option ReadOnly
        write-debug "Global_FrameworkPath did not exist, so created it: $Global_MsbuildPath "
    }
    if(Test-Path variable:global:Global_FrameworkPath35)
	{
        $Global_FrameworkPath35="$env:SystemRoot\Microsoft.NET\Framework$64\v3.5"
        write-debug "Global_FrameworkPath35 exists: $Global_FrameworkPath35"
    }
    else
    {
		New-Variable -Name Global_FrameworkPath35 -Value "$env:SystemRoot\Microsoft.NET\Framework$64\v3.5" -Scope "Global" -option ReadOnly
        write-debug "Global_FrameworkPath35 did not exist, so created it: $Global_MsbuildPath "
    }
	
}

Function Get-ManifestFile
{
	Param(
	[parameter(Mandatory=$true)]          
    [ValidateNotNullOrEmpty()]     
	[string]$ManifestFile)
	If (test-path $ManifestFile) 
	{
		$ManifestFile
	}
	else
	{
		write-host "Could not find $ManifestFile. Please try again"
		Get-ManifestFile
	}
}

Function Set-ManifestFileLocation
{
Param(
	[parameter(Mandatory=$true)]          
    [ValidateNotNullOrEmpty()]     
	[string]$ManifestFile)
	if ($Global_ManifestFile -eq $null)
	{
		 $ManifestFile=Get-ManifestFile $ManifestFile
	}
	
	New-Variable -Name Global_ManifestFile -Value $ManifestFile -Scope "Global" -option ReadOnly

}

Function Copy-Files()
{
    Param([parameter(Mandatory=$true)] [String]$SourcePath, 
        [parameter(Mandatory=$true)] [String]$DestinationDirectory, 
        $deleteFirst=$true, 
        $DoNotStop=$true,
		$CopyOnlyNew=$false)

    ##
    # Author: Lee Adams Date: 14th March 2012
    # Script to robustly copy files. Has the option to delete the directory
    # $DestinationDirectory is always a Directory and never a file
    ##

    ###$ErrorActionPreference ="Stop"
    if(!(Test-Path $SourcePath))
    {
        Throw "$SourcePath does not exist"
    }

    If ((Get-ChildItem $SourcePath).Name)
    {
        $IsDirectory=$false
        ####$TestDestinationPath=$DestinationDirectory
        write-debug "$SourcePath  is a file"
        #Assume Destination is a file as well
        
    }
    else
    {
        $IsDirectory=$true
        write-debug "$SourcePath is a directory or collection of files"
        If(!$DestinationDirectory.EndsWith("\"))
        {
            $DestinationDirectory="$DestinationDirectory\"
        }
        $AllFilesAndDirsInDestinationDirectory="$DestinationDirectory*"
    }

    if (!(Test-Path $DestinationDirectory))
    {
        write-debug "$DestinationDirectory is a directory which does not exist... Creating"
        New-Item $DestinationDirectory -type directory
    }

    if((Test-Path $DestinationDirectory) -and $deleteFirst -and $IsDirectory)
    {
        write-verbose "...Deleting All Items in $DestinationDirectory"
        Remove-Item -Recurse -Force $AllFilesAndDirsInDestinationDirectory
        write-debug "donotstop=$DoNotStop"
        If(!$DoNotStop) {Read-Host "pause"}
    }
	
	
	if (! $CopyOnlyNew) {
        write-verbose "...Copying $SourcePath to $DestinationDirectory"
		Copy-Item $SourcePath $DestinationDirectory -recurse -force
		write-verbose "$SourcePath copied to $DestinationDirectory"
	} else {
		write-verbose "...Copying only NEW items $SourcePath to $DestinationDirectory DOES NOT RECURSE DIRS"
		Compare-Object (ls $SourcePath) (ls $DestinationDirectory) -Property Name, Length, LastWriteTime -passthru | Where { $_.SideIndicator -eq '<=' } | 
		% -Process { 
			Copy-Item $_.FullName $DestinationDirectory 
			write-debug "$($_.FullName)"
		}
		write-verbose "$SourcePath copied to $DestinationDirectory"
	}


}

Function Get-ValidDirectory
{

Param(
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[string]$IsValidDirectory
)
	
	If (test-path $IsValidDirectory)
    {
		$IsValidDirectory
	}
	else
	{
		Get-ValidDirectory
	}
}

Function Test-Directory
{
Param(
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[string]$K2BlackPearlDirectory
)
	
	If (test-path $K2BlackPearlDirectory)
    {
		$K2BlackPearlDirectory
	}
}

Function Test-IsNullOrEmpty
{
	Param($VariableToCheck)

	IF (($VariableToCheck -eq $null) -or ($VariableToCheck.Length -eq 0))
	{
		$true
	}
	else
	{
		$false
	}

}

Function Get-DeterministicGUIDfromString
{
	Param([string]$stringToCreateGUID="The quick brown fox jumps over the lazy dog.")
	###[Reflection.Assembly]::LoadWithPartialName(“System.Text”) | out-null
	
	#This comes from google 
	#http://stackoverflow.com/questions/2190890/how-can-i-generate-guid-for-a-string-values
	#http://stackoverflow.com/questions/10521061/how-to-get-a-md5-checksum-in-powershell
	
	$md5 = [System.Security.Cryptography.MD5]::Create();
	###using (MD5 md5 = MD5.Create())
   #{
    ###byte[] hash = md5.ComputeHash(Encoding.Default.GetBytes(input));
	$defaultEncoding = new-object -TypeName System.Text.UTF8Encoding
	$hash = $md5.ComputeHash($defaultEncoding.GetBytes($stringToCreateGUID));
    ###Guid result = new Guid(hash);
	###[Guid]$DeterministicGUID = new-object -TypeName "Guid"
	[Guid]$DeterministicGUID = [System.GUID]($hash)

    Write-Output "$DeterministicGUID"
    #}
}

export-modulemember -function Update-WebConfig
export-modulemember -function Edit-NodeInXML
export-modulemember -function Get-EnvironmentFromUser
export-modulemember -function Get-Architecture
export-modulemember -function Test-Service
export-modulemember -function Copy-Files
export-modulemember -function Publish-VisualStudioSolution 
export-modulemember -function Add-GlobalVariables 
export-modulemember -function Get-ManifestFile
export-modulemember -function Set-ManifestFileLocation
export-modulemember -function Get-ValidDirectory
export-modulemember -function Test-Directory
export-modulemember -function Test-IsNullOrEmpty
export-modulemember -function Get-EnvironmentSettingFromXML
export-modulemember -function Get-DeterministicGUIDfromString
Add-GlobalVariables

