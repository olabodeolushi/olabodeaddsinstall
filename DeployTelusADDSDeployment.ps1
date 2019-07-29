# ---------------------------------------------------
# Script: DeploytelusADDSDeployment.ps1
# Version: 1.0
# Author: Bode Olushi
# Email: bode.olushi@newsignature.com
# Date:24-07-2019
# Description: This scripts installs Active Directory Domain Controller on a Server
# --------------------------------------------------- 

#Parameters passed from the Telus.ADDSDeployment.psm1 script
param (
    $DomainAdmin,
    $DomainPassword,
    $SafeAdministratorPassword,
    $Domainname,
    $SiteName,
    $ReplicationSourceDC,
    $creds
)

#Concatenate domain administrator username with domain name
#$DomainAdminAddress = $DomainAdmin + "@" +$DomainName
$passwordsec = convertto-securestring $SafeAdministratorPassword -asplaintext -force

#Create a new PSCredential object to hold the domain credentials
#$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainAdminAddress, $DomainPassword

try{

        #Initialize Disks, format new volume to prepare for the AD NTDS Logs
        Get-Disk | where partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
 
        # Set AD install paths
        $drive = get-volume | where { $_.FileSystemLabel -eq “Data” }
        $NTDSpath = $drive.driveletter + ":WindowsNTDS"
        $SYSVOLpath = $drive.driveletter + ":WindowsSYSVOL"
        $Logpath = $drive.driveletter + ":WindowsLog"


        #Install Active Directory 
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools


        #Next# Create Domain Controller and promote the server as a Domain controller
        Import-Module ADDSDeployment
        Install-ADDSDomainController `
        -NoGlobalCatalog:$false `
        -CreateDnsDelegation:$false `
        -Credential $creds `
        -SafeModeAdministratorPassword $passwordsec `
        -CriticalReplicationOnly:$false `
        -DatabasePath $NTDSpath `
        -DomainName $DomainName `
        -InstallDns:$true `
        -LogPath $Logpath `
        -NoRebootOnCompletion:$false `
        -ReplicationSourceDC $ReplicationSourceDC `
        -SiteName $SiteName `
        -SysvolPath $SYSVOLpath `
        -Force:$true
}

catch{
            
       Write-Error -Message $_.Exception.Message
            throw $_.Exception

 }