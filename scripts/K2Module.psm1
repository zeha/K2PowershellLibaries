Function Read-Activities()
{
   [CmdletBinding()]
    Param ($directory="$pwd\")

    ###write-verbose "... Listing all activities in all processes in $directory"

    [Reflection.Assembly]::LoadWithPartialName(“SourceCode.Workflow.Authoring”) | out-null
    $output = ""
    $nl = [Environment]::NewLine
    "Process Name,Activity Name,Action Name"
    
    $fileEntries = Get-ChildItem "$directory*.kprx" |
    foreach { 
        $fileName = $_.Name

        [SourceCode.Workflow.Authoring.Process]$proc = [SourceCode.Workflow.Authoring.Process]::Load("$directory$fileName");
        $proc.Activities | 
        ForEach {
            $activityName = $_.Name
            
            [bool]$printActivity = $true;
                    
            $_.Events | 
            ForEach {
                if ($_.Actions.Count -gt 0)
                {
                    $eventName=$_.Name
                    if ($printActivity)
                    {
                       # write-verbose "Activity: $actName", 
                        $printActivity = $false;
                    }
                    $_.Actions | 
                    ForEach {
                        $actionName = $_.Name
                        $output =  "$output$fileName,$activityName,$actionName$nl"
                        
                    }
                }  
            }  
        }
    }
    
    "$output"
       
}

Function New-K2Packages()
{
<#
   .Synopsis
    This function creates K2 Deployment packages including an msbuild file according to parameters
   .Description
	Finds all .k2proj files in a given directory structure and calls New-K2Package to package them into a output directory structure
    This function requires K2Deploy.msbuild and K2Field.Utilities.Build 
	(available from http://www.k2underground.com/groups/k2_build_and_deploy_msbuild_tasks/default.aspx)
	K2Deploy.msbuild requires changing to match the following 
	<K2Deploy 
			Server="$(Computername)"
			Port="$(Port)"
			ProjectPath="$(K2Project)"
			OutputPath="$(OutputPath)" />
   .Example
        New-K2Packages    "dlx" 5555 "..\..\K2Shared\trunk\" "C:\deployment"
        New-K2Packages    -K2ServerWithAllEnvSettings localhost -SourceCodePathToDiscoverK2ProjFiles C:\tfs\K2.Shared -DeploymentPath C:\tfs\K2.Shared\Deployment
		
   .Parameter     $K2ServerWithAllEnvSettings
        Required. This should be a centralised backed up K2 server which has had all environments added to its env library
		All the settings for all the servers should be populated e.g. MailServer for Live a different setting that the dev or test
   .Parameter     $K2HostServerPort
        defaults to 5555
   .Parameter     $SourceCodePathToDiscoverK2ProjFiles
        Required. The Path to the sourcecode repository for your project where every k2proj file will have a deployment package created
   .Parameter      $DeploymentPath
        Required. The root directory where the project's deployment package will be created.
		It must be a directory and works without the final backslash
		Currently the deployment package is hard coded to K2 Deployment Package.msbuild within each sub directory created
		Subdirectories will have the same name as each .k2proj file found
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
   #>
   [CmdletBinding()]
	Param(
    [parameter(Mandatory=$true)]               
    [ValidateNotNullOrEmpty()]   
	[string]$K2ServerWithAllEnvSettings,

	[int]$K2ServerPortWithAllEnvSettings=5555,

    [parameter(Mandatory=$true)]               
    [ValidateNotNullOrEmpty()]    
    [String] $SourceCodePathToDiscoverK2ProjFiles,
   
    [parameter(Mandatory=$true)]               
    [ValidateNotNullOrEmpty()]    
    [String] $DeploymentPath

	)
	
	Write-Verbose "*** New-K2Packages - Starts"
	$CURRENTDIR=pwd
	###trap {write-host "error"+ $error[0].ToString() + $error[0].InvocationInfo.PositionMessage  -Foregroundcolor Red; cd "$CURRENTDIR"; read-host 'There has been an error'; break}

	Write-Verbose "*Finds all .k2proj files in a given directory structure and calls New-K2Package to package them into a output directory structure"
	Get-ChildItem -Path $SourceCodePathToDiscoverK2ProjFiles -Recurse -Include *.k2proj | ForEach-Object {
		$K2ProjName=$_.BaseName
	
		Write-Debug "* About to create Output directory $DeploymentPath\$K2ProjName"
		new-item $DeploymentPath\$K2ProjName -force -type Directory | out-null

		Write-Debug "* About to build $_ to $DeploymentPath\$K2ProjName"
		Write-Debug "New-K2Package $K2ServerWithAllEnvSettings $K2ServerPortWithAllEnvSettings $_ $DeploymentPath\$K2ProjName"

		New-K2Package $K2ServerWithAllEnvSettings $K2ServerPortWithAllEnvSettings $_ $DeploymentPath\$K2ProjName
	}
	Write-Verbose "*** 4.BuildAndPackage - Ends"

}

Function New-K2Package()
{
<#
   .Synopsis
    This function creates a K2 Deployment package including an msbuild file according to parameters
   .Description
    This function requires K2Deploy.msbuild and K2Field.Utilities.Build 
	(available from http://www.k2underground.com/groups/k2_build_and_deploy_msbuild_tasks/default.aspx)
	K2Deploy.msbuild requires changing to match the following 
	<K2Deploy 
			Server="$(Computername)"
			Port="$(Port)"
			ProjectPath="$(K2Project)"
			OutputPath="$(OutputPath)" />
   .Example
        New-K2Package    "dlx" 5555 "..\..\K2Shared\trunk\SmO\K2Shared.SmO.k2proj" ".\k2 blackpearl\msbuild\All"
        New-K2Package    -K2ServerWithAllEnvSettings dlx -K2Project "..\..\K2Shared\trunk\SmO\K2Shared.SmO.k2proj" -OutputPath ".\k2 blackpearl\msbuild\All"
		
   .Parameter     $K2ServerWithAllEnvSettings
        Required. This should be a centralised backed up K2 server which has had all environments added to its env library
		All the settings for all the servers should be populated e.g. MailServer for Live a different setting that the dev or test
   .Parameter     $K2HostServerPort
        defaults to 5555
   .Parameter     $K2Project
        Required. The k2proj file for the project you wish to build a deployment package for. Must end in .k2proj
   .Parameter      $OutputPath
        Required. The place where the project's deployment package will be created.
		It must be a directory and works without the final backslash
		Currently the deployment package is hard coded to K2 Deployment Package.msbuild
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
   #>
   [CmdletBinding()]
   Param([parameter(Mandatory=$true)] [string]$K2ServerWithAllEnvSettings,  
   [int]$K2HostServerPort=5555, 
   [parameter(Mandatory=$true)] [string]$K2Project, 
   [parameter(Mandatory=$true)] [string]$OutputPath)
   
   Write-Debug "New-K2Package"
   Write-Verbose "*** CREATE PACKAGE AGAINST $K2ServerWithAllEnvSettings settings port: $K2HostServerPort "
   Write-Verbose "*** ABOUT TO Create package for project $K2Project to using $Global_FrameworkPath\MSBUILD outputting here: $OutputPath"	
   
   $K2FieldUtilitiesBuildFolder = "K2Field.Utilities.Build"
   $K2FieldUtilitiesBuildFile = "K2Deploy.msbuild"
   
	& $Global_FrameworkPath\MSBUILD "$Global_MsbuildPath$K2FieldUtilitiesBuildFolder\$K2FieldUtilitiesBuildFile"   /p:Computername=$K2ServerWithAllEnvSettings /p:Port=$K2HostServerPort /p:K2Project=$K2Project /p:OutputPath=$OutputPath

	Write-Verbose "*** Create package for $K2Project - DONE!"
	Write-Verbose "***********************************"
}

Function Publish-K2ServiceType
{
<#
   .Synopsis
    This function deploys a service type according to parameters
   .Description
    This function deploys a service type according to the following parameters
   .Example
        
        Publish-K2ServiceType "c:\WINDOWS\Microsoft.NET\Framework64\v3.5" "C:\installs\RegisterServiceType.msbuild" "localhost" 5555 "5e846dec-170d-4492-bb8c-f1b64600b4e4" "DynamicWebService.ServiceBroker" "Dynamic Web Service" "example desc" "DynamicWebService.ServiceBroker" ".\k2 blackpearl\ServiceBroker\DynamicWebService.dll"
         
   .Parameter     $NetFrameworkPath
        Defaults to "c:\WINDOWS\Microsoft.NET\Framework64\v3.5"
   .Parameter     $MSBUILDCONFIG
        The full path to the RegisterServiceType.msbuild file
   .Parameter     $K2SERVER
        defaults to DLX
   .Parameter     $K2SERVERPORT
        defaults to 5555
   .Parameter      $SERVICETYPESYSTEMNAME
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter     $SERVICETYPEGUID
        Required. This Guid does not have to be the same from environment to environment
        but it helps for the deployServiceInstance scripts to know what the service type GUID is, 
        plus there is no harm in explicitly setting this guid.
   .Parameter      $SERVICETYPESYSTEMNAME
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter      $SERVICETYPEDISPLAYNAME
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter     $SERVICETYPEDESCRIPTION
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter     $SERVICETYPECLASSNAME 
        Required. It is very important to get this correct. If wrong it will STILL LOOK LIKE IT WORKS
        BUT you will get errors when running methods. If unsure what this value should be, register it
        manually and look at the xml (in the database if neccessary)
   .Parameter     $assembliesSourcePath
        The relative or absolute path to the .dll excluding the full assembly name. Everything gets copied
   .Parameter     $assembliesTargetPath
        Required. 
        Where to put it. Normally in the pf\blackpearl\ServiceBroker or a subdirectory off this.
   .Parameter     $serviceTypeAssemblyName
        Required. 
        The full assembly name of the dll.
   .Parameter     $CopyOnly
        Defaults to false. Whether to just copy the dll. Useful in load balanced environments
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
   #>
   [CmdletBinding()]
   Param([string]$NetFrameworkPath="c:\WINDOWS\Microsoft.NET\Framework64\v3.5", 
   [parameter(Mandatory=$true)] [string]$MSBUILDCONFIG, 
   [string]$K2SERVER="dlx", 
   [int]$K2HOSTSERVERPORT=5555,
   [parameter(Mandatory=$true)] [string]$SERVICETYPEGUID, 
   [parameter(Mandatory=$true)] [string]$SERVICETYPESYSTEMNAME, 
   [parameter(Mandatory=$true)] [string]$SERVICETYPEDISPLAYNAME, 
   [parameter(Mandatory=$true)] [string]$SERVICETYPEDESCRIPTION, 
   [parameter(Mandatory=$true)] [string]$SERVICETYPECLASSNAME, 
   [parameter(Mandatory=$false)] [string]$assembliesSourcePath="",
   [parameter(Mandatory=$true)] [string]$assembliesTargetPath,
   [parameter(Mandatory=$true)] [string]$serviceTypeAssemblyName, 
   [parameter(Mandatory=$false)] [bool]$CopyOnly=$false)

	write-debug  "**Publish-K2ServiceType()"
	
	write-debug  "Replacing {BlackPearlDir} with the global variable of $Global_K2BlackPearlDir"
    $assembliesTargetPath=$assembliesTargetPath.Replace("{BlackPearlDir}", "$Global_K2BlackPearlDir")
    $assembliesTargetPath=$assembliesTargetPath.Replace("\\", "\")
    If(!$assembliesTargetPath.EndsWith("\"))
    {
        $assembliesTargetPath="$AssemblyTargetFullPath\"
    }
    $AssemblyTargetFullPath="$assembliesTargetPath$serviceTypeAssemblyName"

    # ----- About to register ServiceType
    Write-verbose "**** COPYING DLL for: $SERVICETYPEDISPLAYNAME"
    ###if (!(Test-Path -path $assembliesTargetPath)) {New-Item $assembliesTargetPath -Type Directory}
    If($assembliesSourcePath -eq "")
	{
		write-debug "set to not copy assemblies."
	}
    elseif($assembliesSourcePath.EndsWith("\*"))
    {
        #Do nothing this is the prefered format
    }
    elseif($assembliesSourcePath.EndsWith("\"))
    {
        $assembliesSourcePath="$assembliesSourcePath*"
    }
    else ###(!$assembliesSourcePath.EndsWith("\"))
    {
        $assembliesSourcePath="$assembliesSourcePath\*"
    }
    If($assembliesSourcePath -ne "")
    {
        write-debug "Copy-Files $assembliesSourcePath $assembliesTargetPath $true $true $true"
        Copy-Files $assembliesSourcePath $assembliesTargetPath $true $true $false -verbose ###-debug
    }
	
	if ($CopyOnly)
	{
		Write-Debug "Only set to copy files"
		
	}
	else
	{
	    Write-Verbose "**** ABOUT TO REGISTER SERVICE TYPE"
		
			
	    write-debug "& $NetFrameworkPath\MSBUILD $MSBUILDCONFIG /p:K2SERVER=$K2SERVER /p:K2HostServerPort=$K2HOSTSERVERPORT /p:ServiceTypeGuid=$SERVICETYPEGUID /p:ServiceTypeSystemName=$SERVICETYPESYSTEMNAME /p:ServiceTypeDisplayName=$SERVICETYPEDISPLAYNAME /p:ServiceTypeDescription=$SERVICETYPEDESCRIPTION /p:ServiceTypeAssemblyPath=$AssemblyTargetFullPath /p:ServiceTypeClassName=$SERVICETYPECLASSNAME "
	    $OutPut = & $NetFrameworkPath\MSBUILD $MSBUILDCONFIG /p:K2SERVER=$K2SERVER /p:K2HostServerPort=$K2HOSTSERVERPORT /p:ServiceTypeGuid=$SERVICETYPEGUID /p:ServiceTypeSystemName=$SERVICETYPESYSTEMNAME /p:ServiceTypeDisplayName=$SERVICETYPEDISPLAYNAME /p:ServiceTypeDescription=$SERVICETYPEDESCRIPTION /p:ServiceTypeAssemblyPath=$AssemblyTargetFullPath /p:ServiceTypeClassName=$SERVICETYPECLASSNAME
	    $OutPut = [string]::join("`n", $OutPut)
		write-debug "finished"
	    If ($OutPut.Contains("0 Error(s)"))
	    {
			write-debug "deploy succeeded"
			$OutPut = " Msbuild reports that the service Type $SERVICETYPEDISPLAYNAME Deployed successfully $OutPut"
	        
	        $colour="Green"
	        If (!($OutPut.Contains("0 Warning(s)")))
	        {
				Write-warning "***With Warnings: $OutPut"
	        }
			else
			{
				Write-Verbose "$OutPut" 
			}
	    }
	    else
	    {
			write-debug "deploy failed"
			$message="There was an error deploying the service Type '$SERVICETYPEDISPLAYNAME': $OutPut"
	        Throw $message
	    }
	}
    Write-Debug "**Publish-K2ServiceType() - Finished"
}

Function Publish-K2ServiceInstance
{
<#
   .Synopsis
    This function deploys a service instance via msbuild and a custom deployment project according to parameters
   .Description
    This function deploys a service instance according to the following parameters
   .Example
        Publish-K2ServiceInstance "c:\WINDOWS\Microsoft.NET\Framework64\v3.5"  "DLX" 5555 "900a3faf-8765-4a32-8a1d-b02008e06003"  "8e7610de-76ae-433e-9efa-eddcdd12848f" systemName displayName description "true" "SqlConnectionString|SmartObjectConnectionString" "Data Source=dlx;Initial Catalog=K2ProcessData;Integrated Security=SSPI;|Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=localhost;Port=5555;" "true|true" "|" 
   .Parameter $NetFrameworkPath
        Defaults to "c:\WINDOWS\Microsoft.NET\Framework64\v3.5",
   .Parameter $K2SERVER
        Defaults to "dlx"
   .Parameter          $K2HOSTSERVERPORT
        Defaults to 5555
   .Parameter          $SERVICETYPEGUID
        Required. This must match an existing service type guid
   .Parameter          $SERVICEINSTANCEGUID
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter          $SERVICEINSTANCESYSTEMNAME
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter          $SERVICEINSTANCEDISPLAYNAME
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter          $SERVICEINSTANCEDESCRIPTION
        Required. The value you would enter if Registering through the SmartObject service tester
   .Parameter          $CONFIGIMPERSONATE
        Required. The text 'true' or 'false', as if Registering through the SmartObject service tester
   .Parameter         $CONFIGKEYNAMES
        Required. A list of delimited names. These names should be identical to the names you are asked
        to provide when Registering through the SmartObject service tester.
   .Parameter          $CONFIGKEYVALUES
        Required. A list of delimited values. These valuess should be identical to the values you provide 
        when Registering through the SmartObject service tester.
    .Parameter         $CONFIGKEYSREQUIRED
        Required. Usually true|true. These boolean should be the same as the values that are reported against 
        each name when Registering through the SmartObject service tester.
    .Parameter 
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()] 
    Param(  [string]$NetFrameworkPath="c:\WINDOWS\Microsoft.NET\Framework64\v3.5",
   	    [parameter(Mandatory=$true)] [string]$MSBUILDCONFIG, 
            [string]$K2SERVER="dlx", 
            [int]$K2HOSTSERVERPORT=5555,
            [parameter(Mandatory=$true)] [string]$SERVICETYPEGUID,
            [parameter(Mandatory=$true)] [string]$SERVICEINSTANCEGUID,
            [parameter(Mandatory=$true)] [string]$SERVICEINSTANCESYSTEMNAME,
            [parameter(Mandatory=$true)] [string]$SERVICEINSTANCEDISPLAYNAME,
            [parameter(Mandatory=$true)] [string]$SERVICEINSTANCEDESCRIPTION,
            [parameter(Mandatory=$true)] [string]$CONFIGIMPERSONATE,
            [parameter(Mandatory=$true)] [string]$CONFIGKEYNAMES,
            [parameter(Mandatory=$true)] [string]$CONFIGKEYVALUES,
            [parameter(Mandatory=$true)] [string]$CONFIGKEYSREQUIRED, 
            [string]$CONFIGKEYDELIMITER="|")

    
    Write-Debug "**Publish-K2ServiceInstance() - Start"
   $CONFIGKEYVALUES=$CONFIGKEYVALUES.Replace("=", "{[equals]}" ).Replace(";","{[semicolon]}")
                 
    Write-Verbose "** ABOUT TO REGISTER SERVICEINSTANCE"
    Write-Debug "$NetFrameworkPath\MSBUILD $MSBUILDCONFIG /p:K2SERVER=$K2SERVER /p:K2HostServerPort=$K2HOSTSERVERPORT /p:ServiceTypeGuid=$SERVICETYPEGUID /p:ServiceInstanceGuid=$SERVICEINSTANCEGUID /p:ServiceInstanceSystemName=$SERVICEINSTANCESYSTEMNAME /p:ServiceInstanceDisplayName=$SERVICEINSTANCEDISPLAYNAME /p:ServiceInstanceDescription=$SERVICEINSTANCEDESCRIPTION /p:ConfigImpersonate=$CONFIGIMPERSONATE /p:ConfigKeysRequired=$CONFIGKEYSREQUIRED /p:ConfigKeyNames=$CONFIGKEYNAMES  /p:ConfigKeyValues=$CONFIGKEYVALUES  /p:ConfigKeyDelimiter=$CONFIGKEYDELIMITER  "
    $OutPut = & $NetFrameworkPath\MSBUILD $MSBUILDCONFIG /p:K2SERVER=$K2SERVER /p:K2HostServerPort=$K2HOSTSERVERPORT /p:ServiceTypeGuid=$SERVICETYPEGUID /p:ServiceInstanceGuid=$SERVICEINSTANCEGUID /p:ServiceInstanceSystemName=$SERVICEINSTANCESYSTEMNAME /p:ServiceInstanceDisplayName=$SERVICEINSTANCEDISPLAYNAME /p:ServiceInstanceDescription=$SERVICEINSTANCEDESCRIPTION /p:ConfigImpersonate=$CONFIGIMPERSONATE /p:ConfigKeysRequired=$CONFIGKEYSREQUIRED /p:ConfigKeyNames=$CONFIGKEYNAMES  /p:ConfigKeyValues=$CONFIGKEYVALUES  /p:ConfigKeyDelimiter=$CONFIGKEYDELIMITER  
    $OutPut = [string]::join("`n", $OutPut)
	
	write-debug "**finished registering service instance"
    If ($OutPut.Contains("0 Error(s)"))
    {
		write-debug "deploy succeeded"
		$OutPut = " Msbuild reports that the service Instance '$SERVICEINSTANCEDISPLAYNAME' Deployed successfully: $OutPut"
        
        If (!($OutPut.Contains("0 Warning(s)")))
        {
			Write-warning "***With Warnings: $OutPut"
        }
		else
		{
			Write-Verbose "$OutPut" 
		}
    }
    else
    {
		write-debug "deploy failed"
		$message="There was an error deploying the service Instance '$SERVICEINSTANCEDISPLAYNAME': $OutPut"
        Throw $message
    }
    Write-Debug "**Publish-K2ServiceInstance() - Finished"
}

Function Open-K2ServerConection
{
<#
   .Synopsis
    This function is depriciated. Use either Open-K2WorkflowClientConnectionVerboseError or Open-K2WorkflowClientConnectionThrowError
   .Description
        This function is depriciated. Use either Open-K2WorkflowClientConnectionVerboseError or Open-K2WorkflowClientConnectionThrowError
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param($k2con,
	$k2Host="localhost",
	$k2WorkflowPort=5252)

	Open-K2WorkflowClientConnectionVerboseError $k2con $k2Host $k2WorkflowPort
}

Function Open-K2WorkflowClientConnectionVerboseError
{
<#
   .Synopsis
    This function opens a connection to the k2 wf server according to parameters
   .Description
    This function opens a connection to the k2 wf server according to parameters. It will not throw an error if the connection open fails
   .Example
        Open-K2WorkflowClientConnectionVerboseError $k2con "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"
   .Parameter  $k2WorkflowPort
        Defaults to 5252
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param($k2con,
	$k2Host="localhost",
	$k2WorkflowPort=5252)

	trap {write-verbose "..Failed-Try again"; "error"; continue}
	Open-K2WorkflowClientConnectionThrowError $k2con $k2Host $k2WorkflowPort
}

Function Open-K2WorkflowClientConnectionThrowError
{
<#
   .Synopsis
    This function opens a connection to the k2 wf server according to parameters
   .Description
    This function opens a connection to the k2 wf server according to parameters. It will throw an error if the connection open fails
   .Example
        Open-K2WorkflowClientConnectionThrowError $k2con "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"
   .Parameter  $k2WorkflowPort
        Defaults to 5252
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param($k2con,
	$k2Host="localhost",
	$k2WorkflowPort=5252)

	$k2con.Open($k2Host, "Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$k2Host;Port=$k2WorkflowPort");
		
}

Function Open-K2SMOManagementConnectionVerboseError
{
<#
   .Synopsis
    This function opens a connection to the k2 wf server according to parameters
   .Description
    This function opens a connection to the k2 wf server according to parameters. It will not throw an error if the connection open fails
   .Example
        Open-K2WorkflowClientConnectionVerboseError $k2con "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"
   .Parameter  $k2WorkflowPort
        Defaults to 5252
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param([SourceCode.SmartObjects.Management.SmartObjectManagementServer]$k2SMOServer,
	$k2Host="localhost",
	$k2SMOManagementPort=5555)

	trap {write-verbose "..Failed-Try again"; "error"; continue}
	Open-K2SMOManagementConnectionThrowError $k2SMOServer $k2Host $k2SMOManagementPort
}

function Test-K2Connection
{
   [CmdletBinding()]
   param($k2Connection)
	trap {write-debug "$error[0]"; write-Output $false; continue}
	[bool]$IsConnected = $k2Connection.Connection.IsConnected
	Write-Verbose	 "Test-K2Connection: K2Server Connected? $IsConnected"
	Write-Output $IsConnected
}

Function Get-K2SMOManagementConnectionThrowError
{
<#
   .Synopsis
    This function opens a connection to the k2 wf server according to parameters
   .Description
    This function opens a connection to the k2 wf server according to parameters. It will throw an error if the connection open fails
   .Example
        Open-K2WorkflowClientConnectionThrowError $k2con "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"
   .Parameter  $k2WorkflowPort
        Defaults to 5252
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param([Parameter(Position=0)][string]$k2Host="localhost",
	[Parameter(Position=1)][int]$k2SMOManagementPort=5555)

	Write-debug "** SourceCode.SmartObjects.Management"
	[Reflection.Assembly]::LoadWithPartialName(“SourceCode.SmartObjects.Management”) | out-null
	
	Write-Debug "SmartObjectManagementServer"
	[SourceCode.SmartObjects.Management.SmartObjectManagementServer]$k2SMOServer = New-Object SourceCode.SmartObjects.Management.SmartObjectManagementServer

	Write-Debug "Creating the connection"
	$k2SMOServer.CreateConnection();
	
	Write-Debug "Opening the connection"
	$k2SMOServer.Connection.Open("Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$k2Host;Port=$k2SMOManagementPort");

	$IsConnected = $k2SMOServer.Connection.IsConnected
	Write-Debug	 "Is the SmartObjectManagementServer Connected? $IsConnected"
	Write-Output $k2SMOServer
}

Function Get-CategoryServer
{
<#
   .Synopsis
    This function TODO
   .Description
    This function TODO
   .Example
        Open-K2WorkflowClientConnectionThrowError $k2con "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"
   .Parameter  $k2WorkflowPort
        Defaults to 5252
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param([Parameter(Position=0)][string]$k2Host="localhost",
	[Parameter(Position=1)][int]$k2SMOManagementPort=5555)

	Write-debug "** SourceCode.SmartObjects.Management"
	[Reflection.Assembly]::LoadWithPartialName(“SourceCode.Categories.Client”) | out-null
	
	Write-Debug "SmartObjectManagementServer"
	[SourceCode.Categories.Client.CategoryServer]$k2SMOServer = New-Object SourceCode.Categories.Client.CategoryServer

	Write-Debug "Creating the connection"
	$k2SMOServer.CreateConnection();
	
	Write-Debug "Opening the connection"
	$k2SMOServer.Connection.Open("Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$k2Host;Port=$k2SMOManagementPort");

	$IsConnected = $k2SMOServer.Connection.IsConnected
	Write-Debug	 "Is the SmartObjectManagementServer Connected? $IsConnected"
	Write-Output $k2SMOServer
}

Function Delete-SmartObject
{
<#
   .Synopsis
    This function Delete-SmartObject from the k2 server according to parameters
   .Description
    This function Delete-SmartObject according to parameters.
   .Example
        Publish-K2SMOsFromServiceInstance "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"[SourceCode.SmartObjects.Management.SmartObjectManagementServer]
   .Parameter  $k2WorkflowPort
        Defaults to 5252[SourceCode.Categories.Client.CategoryServer]
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param(	[Parameter(Mandatory=$true)][string]$SmartObjectName,
	[Parameter(Mandatory=$false)]$SmartObjectManagementServer,
	[Parameter(Mandatory=$false)]$CategoryManagementServer,
	[Parameter(Mandatory=$false)][string]$k2Host="localhost",
	[Parameter(Mandatory=$false)][int]$k2ManagementPort=5555
)

Write-debug "** Delete-SmartObject()"

if (!(Test-K2Connection $SmartObjectManagementServer))
{
	$SmartObjectManagementServer = Get-K2SMOManagementConnectionThrowError $k2Host $k2ManagementPort
}
[SourceCode.SmartObjects.Management.SmartObjectExplorer]$smartObjects = $SmartObjectManagementServer.GetSmartObjects($SmartObjectName);

	$smartObjects.SmartObjects | ForEach-Object {

		$SmartObjectManagementServer.DeleteSmartObject($_.Guid, $true);

        if (!(Test-K2Connection $CategoryManagementServer))
		{
			$CategoryManagementServer = Get-CategoryServer $k2Host $k2ManagementPort
		}
		
		Write-Debug "$SmartObjectType"
        $CategoryManagementServer[2].DeleteCategoryData($_.Guid.ToString(), [SourceCode.Categories.Client.CategoryServer+dataType]::SmartObject);

    }
}

Function Publish-K2SMOsFromServiceInstance
{
<#
   .Synopsis
    This function Publish-K2SMOsFromServiceInstance k2 server according to parameters
   .Description
    This function Publish-K2SMOsFromServiceInstance k2 wf server according to parameters.
   .Example
        Publish-K2SMOsFromServiceInstance "DLX" 5555
   .Parameter $k2con
   	    Required the instansiated but not open connection 
   .Parameter $k2Host
        Defaults to "localhost"
   .Parameter  $k2WorkflowPort
        Defaults to 5252
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param([parameter(Mandatory=$true)] [Guid]$ServiceTypeGUID,
		[parameter(Mandatory=$true)] [Guid]$ServiceInstanceGUID,
	$k2Host="localhost",
	$k2SMOManagementPort=5555,
	[bool]$forceOverwriteExistingSMOs=$true,
	[bool]$determinGUIDFromName=$true
)

Write-debug "** Publish-K2SMOsFromServiceInstance()"
write-verbose "Publishing K2 SMOs From Service Instance- This may take a while to register assemblies"
Write-debug "** SourceCode.SmartObjects.Authoring"
[Reflection.Assembly]::LoadWithPartialName(“SourceCode.SmartObjects.Authoring”) | out-null



###	[SourceCode.SmartObjects.Management.SmartObjectManagementServer]$SmartObjectManagementServer = New-Object SourceCode.SmartObjects.Management.SmartObjectManagementServer
	###Open-K2SMOManagementConnectionThrowError -$k2SMOServer $SmartObjectManagementServer -k2Host $k2Host -k2SMOManagementPort $k2SMOManagementPort
	
	###Write-Debug "SmartObjectManagementServer"
	###[SourceCode.SmartObjects.Management.SmartObjectManagementServer]$SmartObjectManagementServer= New-Object SourceCode.SmartObjects.Management.SmartObjectManagementServer

	###Write-Debug "Creating the connection"
	###$SmartObjectManagementServer.CreateConnection();
	
	###Write-Debug "Opening the connection"
	###$SmartObjectManagementServer.Connection.Open("Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$k2Host;Port=$k2SMOManagementPort");


	$SmartObjectManagementServer = Get-K2SMOManagementConnectionThrowError $k2Host $k2SMOManagementPort
	#Wierd powershell behaviour when returning a overloaded class. It returns an array of which the item we need is the third element
	$IsConnected = $SmartObjectManagementServer[2].Connection.IsConnected
	Write-Debug	 "Is the SmartObjectManagementServer Connected? $IsConnected"
	
	[SourceCode.SmartObjects.Management.ServiceExplorerLevel]$ServiceExplorerLevelFull = [SourceCode.SmartObjects.Management.ServiceExplorerLevel]::Full
	Write-Debug "$ServiceExplorerLevelFull"
	
	
	[String]$ServiceExplorerXML = $SmartObjectManagementServer[2].GetServiceExplorer();

	Write-Debug "Creating service explorer"
    [SourceCode.SmartObjects.Authoring.ServiceExplorer]$serviceExplorer = [SourceCode.SmartObjects.Authoring.ServiceExplorer]::Create($ServiceExplorerXML);
	##ServiceExplorer serviceExplorer = ServiceExplorer.Create(this._smoManagementServer.GetServiceExplorer(ServiceExplorerLevel.Full));
	
	
	Write-Debug "Creating service type"
    [SourceCode.SmartObjects.Authoring.Service]$service = $serviceExplorer.Services[$ServiceTypeGUID];
	
	
	Write-Debug "Creating service Instance"
    [SourceCode.SmartObjects.Authoring.ServiceInstance]$serviceInstance = $service.ServiceInstances[$ServiceInstanceGUID];
    
	
	Write-Debug "looping through service objects"
    $serviceInstance.ServiceObjects | ForEach-Object {
	
		Write-Debug "$($_.DisplayName)"
        [SourceCode.SmartObjects.Authoring.SmartObjectDefinition]$smo = [SourceCode.SmartObjects.Authoring.SmartObjectDefinition]::Create($_);
		$smo.Guid = Get-DeterministicGUIDfromString "$($_.DisplayName)"
		$smo.Metadata.Guid = $smo.Guid;
        $smo.Name = [SourceCode.SmartObjects.Authoring.SmartObjectDefinition]::GetNameFromDisplay($_.Name);
        $smo.Metadata.DisplayName = $_.DisplayName;
		If ($forceOverwriteExistingSMOs)
		{
			Delete-SmartObject -SmartObjectManagementServer $SmartObjectManagementServer[2] -SmartObjectName $smo.Name
		}
        $SmartObjectManagementServer[2].PublishSmartObject($smo.ToSmartObjectDeployXml(), $service.DisplayName);
    }
	
	Write-Debug "End Publish-K2SMOsFromServiceInstance"
}

Function Test-K2Server
{
   [CmdletBinding()]
Param(
[string]$k2Host="localhost", 
[int]$k2WorkflowPort=5252, 
[int]$SecondsToWaitForResponse=100
)
Write-debug "** Test-K2Server()"
write-verbose "Testing the K2 server - This may take a while to register assemblies"
[Reflection.Assembly]::LoadWithPartialName(“SourceCode.Workflow.Client”) | out-null

	Write-Verbose "**** Trying to open a connection for $SecondsToWaitForResponse seconds to allow time for the K2 service to start up"
	$x=0
	$success =$false
	$k2con = New-Object SourceCode.Workflow.Client.Connection
	while (($x -lt $SecondsToWaitForResponse) -and (!$success))
	{
		$success = $true
		$error.clear();
		$errorMsg="";
		
		$errorMsg = Open-K2WorkflowClientConnectionVerboseError $k2con $k2Host $k2WorkflowPort
		If($errorMsg -eq "error")
		{
			$success = $false
		}
			
		sleep 1;
		$x++ ;
	}
	If ($Success)
	{
		write-verbose "* K2 server is up - now closing the connection *"
		$k2con.Dispose()
	}
	else
	{
		Throw (New-Object System.Management.Automation.RuntimeException "K2 server never responded")
	}
}

Function Test-K2BlackPearlDirectorys
{
	$K2BlackPearlDirectory=(Get-ItemProperty "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SourceCode\BlackPearl\BlackPearl Host Server\").InstallDir 
    If (Test-IsNullOrEmpty($K2BlackPearlDirectory))  
    {
		#Returns the setting if it is found
    Test-Directory -K2BlackPearlDirectory "D:\Program Files\K2 blackpearl\Host Server\"
    Test-Directory -K2BlackPearlDirectory "D:\Program Files (x86)\K2 blackpearl\Host Server\"
    Test-Directory -K2BlackPearlDirectory "C:\Program Files\K2 blackpearl\Host Server\"
    Test-Directory -K2BlackPearlDirectory "C:\Program Files (x86)\K2 blackpearl\Host Server\"
	}
	else
	{
		$K2BlackPearlDirectory
	}
}

Function Set-K2BlackPearlDirectory
{
	
	$K2BlackPearlDirectory= Test-K2BlackPearlDirectorys 
	If (Test-IsNullOrEmpty($K2BlackPearlDirectory))  
    {
		Write-Host "Please Type in the path for the K2 Blackpearl directory. E.g. Z:\Program Files (x86)\K2 blackpearl"
		$K2BlackPearlDirectory=Get-ValidDirectory
	}
	If(!$K2BlackPearlDirectory.EndsWith("\"))
    {
		$K2BlackPearlDirectory="$K2BlackPearlDirectory\"
	}
    $K2BlackPearlDirectory=$K2BlackPearlDirectory.Replace("\Host Server","\").Replace("\\", "\")
	if(Test-Path variable:global:Global_K2BlackPearlDir)
	{
		$Global_K2BlackPearlDir = "$K2BlackPearlDirectory"
	}
	else
	{
		New-Variable -Name Global_K2BlackPearlDir -Value "$K2BlackPearlDirectory" -Scope "Global" -option ReadOnly
	}
}

Function Restart-K2Server()
{
<#
   .Synopsis
    This function restarts the k2 server and wait until it is responding before returning control
   .Description
    This function restarts the k2 server and wait until it is responding before returning control.
    
    It uses the SourceCode.Workflow.Client to keep retrying to open a connection every second, until it suceeds
    It defaults to localhost and port 5252 and retries the k2server up to 100 times.
    Parameters can be provided for all 3 if required
    It can also prompt the user if they want to do this.
   .Example
        RestartK2ServerAndWait -Prompt $true
   .Example
        RestartK2ServerAndWait "dlx" 5252 25 $false
   .Parameter $k2Host
            Defaults to localhost, not entirely sure it is useful to override this.
   .Parameter $k2WorkflowPort
            Defaults to 5252
   .Parameter $SecondsToWaitForResponse
        How long do you want to wait before the script errors. Defaults to 100
   .Parameter $Prompt
        Are you absolutely sure you want to do this? Defaults to not prompting.
        Comes in useful as sometimes Service Broker dlls are in use by the server and sometimes they are not.
        If True it will also check if broker tools are running and prompt the user to shut them down
   .ConsoleMode $ConsoleMode
        Set this to true if this the K2 server is a windows 7 dev machine
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>
   [CmdletBinding()]
Param(
[bool]$WaitUntilRestart=$true,
[string]$k2Host="localhost", 
[int]$k2WorkflowPort=5252, 
[int]$SecondsToWaitForResponse=100, 
[bool]$Prompt=$false, 
[bool]$ConsoleMode=$false)


    $EnvironmentChoice=0
    If($Prompt -eq $true) 
    {
        $title = "Restart K2 server?"
        $message= "Would you like to restart the K2 server?"
        $options =@('&Yes','&No')
        $PromptOptions = [System.Management.Automation.Host.ChoiceDescription[]]($options)
        $EnvironmentChoice = $host.ui.PromptForChoice($title, $message, $PromptOptions, 0) 
    }
    If(($EnvironmentChoice -eq 0)) 
    {        
        $blackPearlServiceName="K2 blackpearl Server"
		
		if ($ConsoleMode -eq $true)
		{
			$a = get-process "K2HostServer"

			if ($a -ne $null)
			{
				
				Write-debug "**** Console Window running"
				stop-process $a.id -force
				# Anoyingly the next line will not work as the process is killed by k2 still seems to be up
				wait-process $a.id -erroraction:silentlycontinue

			}
			throw "Not Implemented"
###			$args = '-color:Green'
###			$cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))
###			Start-Process -Credential $cred  "C:\Program Files (x86)\K2 blackpearl\Host Server\Bin\K2HostServer.exe" $args
			
###			Write-Host "**** Console Window now started"
			
		}
		else
		{
			$blackPearlServiceStatus=Test-Service $blackPearlServiceName
			If ($blackPearlServiceStatus -eq "Running")
			{
				write-verbose "**** STOPPING and restarting K2 Server at '$k2Host'"
				Restart-Service -displayname $blackPearlServiceName -EA "Stop"
			}
			elseif ($blackPearlServiceStatus -eq "Stopped")
			{
				write-verbose "**** Starting K2 Server at '$k2Host'"
				Start-Service -displayname $blackPearlServiceName -EA "Stop"
			}
			else
			{
				$message="The K2 server is $blackPearlServiceStatus. Not sure how to handle it when it is not Stopped or Running"
				Throw $message
			}
		}
        write-verbose "**** restart successful******"
		if($WaitUntilRestart)
		{
			Test-K2Server
		}

    }
    If($Prompt)
    {
        If((Get-Process "SmartObject Service Tester" -EA SilentlyContinue) -ne $null) {Read-Host "SmO Tester running. It is advisable to shut it down. Press Enter when done."}
        If((Get-Process "BrokerManagement" -EA SilentlyContinue) -ne $null) {Read-Host "BrokerManagement.exe running. It is advisable to shut it down. Enter when done."}
    }
}

Function Publish-K2ServiceBrokers
{
	<#
   .Synopsis
    This function deploys a list of Service Types and Service Instances
   .Description
    This function deploys a list of Service Types and Service Instances as configured in an XML File.
    
	Sample XML File: TODO

    It uses the above functions to accomplish this TODO: dependencies.
   .Example
        TODO:
   .Example
        TODO:
		
   .Parameter     $NetFrameworkPath
        Defaults to the discovered global setting probably "c:\WINDOWS\Microsoft.NET\Framework64\v3.5"
   .Parameter $Environment
            The environment to deploy to. Uses the XML config to check k2 connection settings and also config sections for environment specific settings.
			If left empty it will prompt
   .Parameter $RestartK2Server
            Defaults to true. Normally needs restarting if files are to be copied
   .Parameter $RootFilePath
        Location of XML file and releative location of service assemblies will use this
	.ManifestFileName
		The name of the XML file including .xml extension
	.ServiceBrokerMsbuildSubDirectory
		The location of required msbuild project, which must be compiled and built first
   .ConsoleMode $ConsoleMode
        Set this to true if this the K2 server is a windows 7 dev machine
        Comes in useful as sometimes Service Broker dlls are in use by the server and sometimes they are not.
        If True it will also check if broker tools are running and prompt the user to shut them down
   .Parameter $CopyOnly
        Defaults to false. Use for load balance node. False on every node except the last one.
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
	#>
		[CmdletBinding()]
		Param(
		
		[parameter(Mandatory=$false)]  
		[string]$NetFrameworkPath=$Global_FrameworkPath35, 
		  
		[String] $Environment,
	 
		[bool]$RestartK2Server=$true,
		$RootFilePath="$null", 
		$ManifestFileName="$null", 
		$ManifestFileRootNode="EnvironmentMetaData",
		$ServiceBrokerMsbuildSubDirectory="..\K2Field.Utilities.ServiceObjectBuilder\MSBuild Folder",
		[Bool]$ConsoleMode=$false,
		[Bool]$prompt=$false,
		[Bool]$CopyOnly=$false
		)
		Write-Debug "Deploy Service Brokers"
		$CURRENTDIR=pwd
		###trap {write-host "error"+ $error[0].ToString() + $error[0].InvocationInfo.PositionMessage  -Foregroundcolor Red; cd "$CURRENTDIR"; read-host 'There has been an error'; break}

		###$ErrorActionPreference ="Stop"
		$ManifestFile="$RootFilePath$ManifestFileName"
		Write-Verbose "** Finding manifest file @ $ManifestFile"

		if($NetFrameworkPath -eq $null)
		{
			Write-Debug "passed in netframe path is null. adding global variable"
            Add-GlobalVariables
            $NetFrameworkPath=$Global_FrameworkPath35
		}
		elseif($NetFrameworkPath -eq "")
		{
			Write-Debug "passed in netframe path is empty. adding global variable"
            Add-GlobalVariables
            $NetFrameworkPath=$Global_FrameworkPath35
            
		}
		else
		{
			Write-Debug "passed in netframe path:  $NetFrameworkPath"
		}
        Write-Debug "NetFrameworkPath is now $NetFrameworkPath"

		If (test-path $ManifestFile) 
		{   
			Write-Verbose "** Manifest file found"
        
			$xml = [xml](get-content $ManifestFile)
			If(($Environment -eq $null) -or ($Environment -eq "") )
			{
        
				Write-Verbose "** No Environment passed in"
				"Environment not passed in, ask the user"
        
				$Environment=Get-EnvironmentFromUser($xml)
			}
			else
			{
				Write-Verbose "**Environment passed in = '$Environment'"
        
			}
        
			$K2SERVER= $xml.$ManifestFileRootNode.Environments.$Environment.K2Host
			$K2HOSTSERVERPORT= $xml.$ManifestFileRootNode.Environments.$Environment.K2HostPort
    
			write-verbose "** copying msbuild files to $Global_MsbuildPath"
			write-debug "Copy-Item $RootFilePath$ServiceBrokerMsbuildSubDirectory\* $Global_MsbuildPath -recurse -force"
			Copy-Item "$RootFilePath$ServiceBrokerMsbuildSubDirectory\*" $Global_MsbuildPath -recurse -force
			write-verbose "** finished copying msbuild files"
    
			If($RestartK2Server -eq $null)
			{
				$RestartK2Server=$true
				[bool]$prompt=$true
			}
			else
			{
				###[bool]$prompt=$false
			}
			if ($RestartK2Server)
			{
				write-debug "Restart-K2Server -WaitUntilRestart $true -Prompt $prompt -ConsoleMode $ConsoleMode"
				Restart-K2Server -WaitUntilRestart $true -Prompt $prompt -ConsoleMode $ConsoleMode
			}
		    
			$delimiter="|"

			@($xml.SelectSingleNode("//ServiceTypes").ChildNodes) | ForEach-Object {
				 write-verbose "Reading Service Type details:"
		 
				 write-debug "deploy:$($_.deploy)  sysname:$($_.systemName)    $($_.guid)    dname:$($_.displayName)   InnerText:$($_.InnerText)  assembly:$($_.assemliesSourcePath)"
				 If([System.Convert]::ToBoolean($_.deploy))
				 {
					$CopySource=$_.assemliesSourcePath;
					$CopySource="$RootFilePath$CopySource"
					if ($_.assembliesSourcePath -ne "")
					{
				
						write-verbose "copy the source from $CopySource"
					}
					else
					{

						write-verbose "DO NOT copy the source from $CopySource"
					}
					Write-verbose "** Deploying Service Type $_.displayName to $K2SERVER port $K2HOSTSERVERPORT"
					write-debug "running Publish-K2ServiceType $NetFrameworkPath $RootFilePath$ServiceBrokerMsbuildSubDirectory\RegisterServiceType.msbuild $K2SERVER $K2HOSTSERVERPORT $($_.guid) $($_.systemName) $($_.displayName) $($_.description) $($_.className) $CopySource $($_.assembliesTargetPath) $($_.serviceTypeAssemblyName) $CopyOnly"
					Publish-K2ServiceType $NetFrameworkPath "$RootFilePath$ServiceBrokerMsbuildSubDirectory\RegisterServiceType.msbuild" $K2SERVER $K2HOSTSERVERPORT $_.guid $_.systemName $_.displayName $_.description $_.className "$CopySource" $_.assembliesTargetPath $_.serviceTypeAssemblyName $CopyOnly
				 }
				 else
				 {
					Write-verbose "** Skipping Service Type   $($_.displayName) as it is configured not to deploy"
				 }
				 $ServiceTypeGUID=$_.guid
         		if ($CopyOnly)
				{
					Write-Debug "only copy dlls so skipping registration"
				}
				else
				{
					 $_.SelectNodes("ServiceInstance") | 
					 foreach { 
						#For every service instance Get the config name values pairs
						$ServiceInstanceKeyValues="";
						$ServiceInstanceKeyRequiredList="";
						$ServiceInstanceKeyNames="";
	            
						If([System.Convert]::ToBoolean($_.deploy))
						{
							write-debug "** Getting Config values for  $($_.systemName)"
	                
							$_.SelectSingleNode("Environment[@name='$Environment']").Config| 
							 foreach { 
								write-debug "Config: $($_.Name) Value:  $($_.value)"
								$ServiceInstanceKeyValue=$_.value
								$ServiceInstanceKeyRequired=$_.keyRequired
								$ServiceInstanceKeyName=$_.name
								write-debug "** Found Config values for $ServiceInstanceKeyName value is $ServiceInstanceKeyValue"
								$ServiceInstanceKeyValues="$ServiceInstanceKeyValues$delimiter$ServiceInstanceKeyValue";
								$ServiceInstanceKeyRequiredList="$ServiceInstanceKeyRequiredList$delimiter$ServiceInstanceKeyRequired";
								$ServiceInstanceKeyNames="$ServiceInstanceKeyNames$delimiter$ServiceInstanceKeyName";
	                    
							 }#end loop config namevalues
	                 
							 $ServiceInstanceKeyValues=$ServiceInstanceKeyValues.Replace("{BlackPearlDir}", "$Global_K2BlackPearlDir")
							 $ServiceInstanceKeyValues=$ServiceInstanceKeyValues.TrimStart($delimiter);
							 $ServiceInstanceKeyRequiredList=$ServiceInstanceKeyRequiredList.TrimStart($delimiter);
							 $ServiceInstanceKeyNames=$ServiceInstanceKeyNames.TrimStart($delimiter);
							 write-debug "ServiceInstanceKeyRequired: $ServiceInstanceKeyRequiredList ListOfNames: $ServiceInstanceKeyNames"
	                 
					 		########################
							########################
							 Write-Verbose "* Deploying Service Instance  $($_.displayName)"
							 ###Param(                        $K2SERVER $K2HOSTSERVERPORT  $SERVICETYPEGUID, $SERVICEINSTANCEGUID,$SERVICEINSTANCESYSTEMNAME,$SERVICEINSTANCEDISPLAYNAME,$SERVICEINSTANCEDESCRIPTION, $CONFIGIMPERSONATE,$CONFIGKEYNAMES,$CONFIGKEYVALUES,                               $CONFIGKEYSREQUIRED)
							 write-debug "Publish-K2ServiceInstance    $NetFrameworkPath  $RootFilePath$ServiceBrokerMsbuildSubDirectory\RegisterServiceInstance.msbuild $K2SERVER $K2HOSTSERVERPORT $ServiceTypeGUID  $($_.guid)                  $($_.systemName)         $($_.displayName)               $($_.description)               true $ServiceInstanceKeyNames $ServiceInstanceKeyValues $ServiceInstanceKeyRequiredList $delimiter"
							 Publish-K2ServiceInstance    $NetFrameworkPath  "$RootFilePath$ServiceBrokerMsbuildSubDirectory\RegisterServiceInstance.msbuild" $K2SERVER $K2HOSTSERVERPORT $ServiceTypeGUID      $_.guid                  $_.systemName         $_.displayName               $_.description               $_.impersonate $ServiceInstanceKeyNames $ServiceInstanceKeyValues $ServiceInstanceKeyRequiredList $delimiter
							 If([System.Convert]::ToBoolean($_.deploySMO))
							{
								Publish-K2SMOsFromServiceInstance $ServiceTypeGUID $_.guid $K2SERVER $K2HOSTSERVERPORT
							}
							 #######################
							 #######################
						 }
						 else
						 {
							write-verbose "** Skipping Service Instance $($_.systemName) as it is configured not to deploy"
						 }   #If Deploy
					 }   #endloop Service Instance
				} #end if not copy only
			}   #endloop Service Type
		}
		else
		{
			Throw "You must have a ServiceBroker Manifest XML file at $ManifestFile"
		}
	}

function Set-K2ServerPermissions
{
<#
   .Synopsis
    This function updates and adds K2 permissions from an xml structure
   .Description
     This function updates and adds K2 permissions from a structure that looks like the following.
    <Users><User admin='true' canimpersonate='true' export='true' >DENALLIX\Administrator</User><User admin='true' canimpersonate='true' export='true' >DENALLIX\mike</User></Users>
	Sample XML schema: TODO
	
    It uses the above functions to accomplish this TODO: dependencies.
   .Example
        Set-K2ServerPermissions "localhost" 5555 "<Users><User admin='true' canimpersonate='true' export='true' >DENALLIX\Administrator</User><User admin='true' canimpersonate='true' export='true' >DENALLIX\mike</User></Users>" -verbose ###-debug
   .Parameter $k2host
            The name of the K2 host server
   .Parameter $k2HostPort
            Defaults to true. Normally needs restarting if files are to be copied
   .Parameter $PermissionSet
        XML looking like the structure above
	.Parameter $ignoreLabel    
        Defaults to the true. When true, this assumes that K2: is the only Security label and will strip any other labels off.
		Use this when your xml file users do not contain a security label
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
	#>
	[CmdletBinding()]
 	Param([string]$k2host="localhost",
    [int]$k2HostPort=5555,  
    [xml]$PermissionSet,
    [bool]$ignoreLabel=$true
    )
	 [Reflection.Assembly]::LoadWithPartialName(“SourceCode.Workflow.Management”) | out-null
    
	 ##TODO: Horrible hack to search ignoring case!
	 [string]$permissionsetstring=$PermissionSet.InnerXml.ToString().ToLower()
	 $PermissionSet=$permissionsetstring
	 $conn = "Integrated=True;IsPrimaryLogin=True;Authenticate=True;EncryptedPassword=False;Host=$k2Host;Port=$k2HostPort"
	 
	 $managementServer = New-Object SourceCode.Workflow.Management.WorkflowManagementServer
	 $managementServer.CreateConnection() | Out-Null
	 $managementServer.Connection.Open($conn) | Out-Null
	  
	 $adminPermissions = $managementServer.GetAdminPermissions()
	 $newAdminPermissions = New-Object SourceCode.Workflow.Management.AdminPermissions
	 
	 
	 #To add permissions we must first get the existing permissions
	 #We then search the existing permissions and see if it matches a node in the XML
	 #If it matches we do nothing, as we will add all the new and existing xml nodes in below
	 #if it doesn't match we add the permission to the permissions collection
	 $adminPermissions | 
 	foreach {
		$currentExistingUser =  $_.UserName.ToLower()
		Write-Debug "Found existing permission for $currentExistingUser"

		if ($ignoreLabel -eq $true)
		{ #If script is set to ignore the security label, then strip it off
			$pos = $currentExistingUser.IndexOf(":")
			$currentExistingUser = $currentExistingUser.Substring($pos+1)
			Write-Debug "Stripped off label : $currentExistingUser"
		}

		$nodeList = $PermissionSet.SelectNodes("//text()[contains(.,'$currentExistingUser')]");
		if ($nodeList.Count -gt 0)
		{
			Write-Verbose "Found user $currentExistingUser in new xml permission set. Not adding them in, as they will be added below"
		}
		else
		{
			Write-Verbose "Could not find user $currentExistingUser in new xml permission set, so Adding them back in"

			$newAdminPermissions.Add($_)
		}
	}
	
	#Now add All new and existing users in the XML
	$nodelist = $PermissionSet.selectnodes("/users/user") # XPath is case sensitive
	foreach ($user in $nodelist)
	{
		$adminPermission = New-Object SourceCode.Workflow.Management.AdminPermission  
		[string]$currentUser = $user.InnerText
		Write-Debug "current new user: $currentUser"
		$adminPermission.UserName = $currentUser
		$adminPermission.Admin = [System.Convert]::ToBoolean($user.GetAttribute("admin"))
		$adminPermission.CanImpersonate = [System.Convert]::ToBoolean($user.GetAttribute("canimpersonate"))
		$adminPermission.Export = [System.Convert]::ToBoolean($user.GetAttribute("export"))
		Write-Verbose "Adding in user $currentUser"
		$newAdminPermissions.Add($adminPermission)    
	}    

	$rightsSet = $managementServer.UpdateAdminUsers($newAdminPermissions) 
	$managementServer.Connection.Dispose()
	Write-Verbose "Server rights set: $rightsSet"
}

Function Set-K2SharePointRestrictedWizards
{
<#
   .Synopsis
    This function Set-K2SharePointRestrictedWizards from the k2 server according to parameters
   .Description
    This function Set-K2SharePointRestrictedWizards according to parameters. It replicates the _layouts/K2/ManageRestrictedWizards.aspx functionality
   .Example
        Set-K2SharePointRestrictedWizards "<Save><Users><User name='K2:Domain\Username1'/><User name='K2:Domain\Username2'/></Users><Wizards><Wizard id='64'/></Wizards></Save>" "Data Source=localhost;Initial Catalog=K2WebDesigner;integrated security=sspi;Pooling=True" 
		Set-K2SharePointRestrictedWizards "<Save><Wizards><Wizard id='7'/></Wizards></Save>" "Data Source=localhost;Initial Catalog=K2WebDesigner;integrated security=sspi;Pooling=True" 
   .Parameter $saveData
   	    Required XML in the format
		<Save> 
			<Users> 
				<User name="K2:Domain\Username1"/> 
				<User name="K2:Domain\Username2"/> 
			</Users> 
			<Wizards> 
				<Wizard id="64"/> 
				<Wizard id="69"/> 
				<Wizard id="48"/> 
			</Wizards> 
		</Save> 

   .Parameter $SQLconnectionString
        Connection string to the K2 Database containing ProcessSaveEventRestrictions stored procedure
		either K2 or K2WebDesigner
   .Notes
        AUTHOR: Lee Adams, K2
      #Requires -Version 2.0
#>  
   [CmdletBinding()]
Param(	[Parameter(Mandatory=$true)][xml]$saveData,
	[Parameter(Mandatory=$true)][string]$SQLconnectionString
)

Write-debug "** Set-K2SharePointRestrictedWizards()"

	[Reflection.Assembly]::LoadWithPartialName(“SourceCode.WebDesigner.Framework”) | out-null
	[Reflection.Assembly]::LoadWithPartialName(“SourceCode.WebDesigner.Framework.SharePoint") | out-null
	$framework = New-Object SourceCode.WebDesigner.Framework.SharePoint.Methods
	[string] $errorMessage = $framework.SaveWizardRestrictions($saveData.OuterXML, $SQLconnectionString);
	Write-Debug "ErrorMessage = '$errorMessage'"
	if ($errorMessage.Length -ne 0)
	{
		Write-Error $errorMessage
	}
}
export-modulemember -function Read-Activities
export-modulemember -function New-K2Package
export-modulemember -function New-K2Packages
export-modulemember -function Publish-K2ServiceType
export-modulemember -function Publish-K2ServiceInstance
export-modulemember -function Restart-K2Server
export-modulemember -function Test-K2Server
export-modulemember -function Open-K2ServerConection
export-modulemember -function Test-K2BlackPearlDirectorys
export-modulemember -function Test-K2BlackPearlDirectory
export-modulemember -function Set-K2BlackPearlDirectory
export-modulemember -function Publish-K2ServiceBrokers
export-modulemember -function Open-K2WorkflowClientConnectionVerboseError
export-modulemember -function Open-K2WorkflowClientConnectionThrowError
export-modulemember -function Open-K2SMOManagementConnectionVerboseError
export-modulemember -function Get-K2SMOManagementConnectionThrowError
export-modulemember -function Publish-K2SMOsFromServiceInstance
Export-ModuleMember -Function Set-K2ServerPermissions
Export-ModuleMember -Function Set-K2SharePointRestrictedWizards
Set-K2BlackPearlDirectory

