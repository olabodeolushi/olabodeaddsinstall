# ---------------------------------------------------
# Script: ADDCInstall.ps1
# Version: 0.1
# Author: Bode Olushi
# Email: bode.olushi@newsignature.com
# Date: 17-07-2019
# Description: This scripts installs Active Directory Domain Controller on a Server
# --------------------------------------------------- 

#Parameters passed from the Telus.ADDSDeployment.psm1 script
param (
    $DomainAdmin,
    $DomainPassword,
    $SafeAdministratorPassword,
    $Domainname,
    $SiteName,
    $ReplicationSourceDC
)

#Convert passwords passed from Telus.ADDSDeployment.psm1 script to secure strings
$SecureDomainPassword = (ConvertTo-SecureString $DomainPassword -AsPlainText -Force)
$SecureSafeAdministratorPassword = (ConvertTo-SecureString $SafeAdministratorPassword -AsPlainText -Force)
$DomainAdminAddress = $DomainAdmin + "@" +$DomainName


#Create a new PSCredential object to hold the domain credentials
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainAdminAddress, $SecureDomainPassword


#Set Static Variables for Getting and Setting IP Address of the Server
$IpAddress=(Test-Connection -ComputerName $env:computername -count 1).ipv4address.IPAddressToString
$NIC = Get-WMIObject Win32_NetworkAdapterConfiguration -computername . | where{$_.IPEnabled -eq $true -and $_.DHCPEnabled -eq $true}
$ip = ($NIC.IPAddress[0]) 
$gateway = $NIC.DefaultIPGateway 
$subnet = $NIC.IPSubnet[0] 
$dns = $NIC.DNSServerSearchOrder


#Get the Prefix Origin Value
$PrefixOriginValue = Get-NetIPAddress | Where-Object {$_.IPAddress -eq $IpAddress} | Select -ExpandProperty PrefixOrigin


#Check if server has a static IP adress set, if not set the TCP/IPv4 properties for the IP address, subnet mask, default gateway and preferred DNS Server
#The default value for PrefixOriginalValue for a server that does not have IP address set to static is Dhcp
#If this is true, it will set the IP address to static and set the subnet mask, default gateway and DNS Server
If($PrefixOriginValue -eq "Dhcp"){
    
    $NIC.EnableStatic($ip, $subnet) 
    $NIC.SetGateways($gateway) 
    $NIC.SetDNSServerSearchOrder($dns) 
    $NIC.SetDynamicDNSRegistration("FALSE")

}
#Set the gateway if the server already has a static IP address set.
else{
    $NIC.SetGateways($gateway) 
    $NIC.SetDNSServerSearchOrder($dns) 
    $NIC.SetDynamicDNSRegistration("FALSE")

}

#Initialize Disks, format new volume to prepare for the AD NTDS Logs
Get-Disk | where partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
 
# Set AD install paths
$drive = get-volume | where { $_.FileSystemLabel -eq “Data” }
$NTDSpath = $drive.driveletter + ":WindowsNTDS"
$SYSVOLpath = $drive.driveletter + ":WindowsSYSVOL"
$Logpath = $drive.driveletter + ":WindowsLog"

#Install Active Directory 
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

#Next,# Create Domain Controller and promote the server as a Domain controller
Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$false `
-Credential $cred `
-SafeModeAdministratorPassword $SecureSafeAdministratorPassword `
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