<# 
 This Sample Code is provided for the purpose of illustration only and is not intended
 to be used in a production environment.  THIS SAMPLE CODE AND ANY RELATED INFORMATION
 ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
 FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive, royalty-free right to use and
 modify the Sample Code and to reproduce and distribute the object code form of the
 Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to
 market Your software product in which the Sample Code is embedded; (ii) to include a
 valid copyright notice on Your software product in which the Sample Code is embedded;
 and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and 
 against any claims or lawsuits, including attorneys’ fees, that arise or result from 
 the use or distribution of the Sample Code. 
#>


##Requires -Version 5

class subscription
{
    [string]$SubscriptionName
    [string]$SubscriptionId
    [string]$TenantId
    [string]$State
    [sqlserver[]]$Servers

    subscription()
    {
    }
    subscription($name, $id, $tenant, $state)
    {
        $this.SubscriptionName = $name
        $this.SubscriptionId = $id
        $this.TenantId = $tenant
        $this.State = $state      
    }
}

class sqlserver
{
    [string]$ServerName
    [string]$ResourceGroup
    [key[]]$Keys
    [database[]]$Databases
    
    sqlserver()
    {     
    }
    sqlserver($servername, $resourcegroupname, $keys, $databases)
    {
        $this.ServerName = $servername
        $this.ResourceGroup = $resourcegroupname
        $this.Keys = $keys
        $this.Databases = $databases
    }
}

class key
{
    [string]$ServerKeyName
    [string]$Type
    [Uri]$Uri
    [string]$Thumbprint   
    [nullable[datetime]]$CreationDate

    key()
    {
    }
    key($server, $type, $uri, $thumbprint, $creationdate)
    {
        $this.ServerKeyName = $server
        $this.Type = $type
        $this.Uri = $uri
        $this.Thumbprint = $thumbprint
        $this.CreationDate = $creationdate
    }
}

class database
{
    [string]$DatabaseName
    [string]$State
    database()
    {
    }
    database($name, $state)
    {
        $this.DatabaseName = $name
        $this.State = $state
    }
}


$result = New-Object System.Collections.ArrayList

Get-AzSubscription | ForEach-Object {
    
    Write-Host "Reading $($_.Name)"
    Set-AzContext -SubscriptionId $_.Id | Out-Null

    [subscription]$sub = [subscription]::new(
        $_.Name,
        $_.Id,
        $_.TenantId,
        $_.State)

    $resourceType = "Microsoft.Sql/servers"
    $server = Get-AzResource -ResourceType $resourceType
    foreach ($s in $server)
    {
        [key[]]$keys = @()    
        $vaultKeys = Get-AzSqlServerKeyVaultKey -ServerName $s.Name -ResourceGroupName $s.ResourceGroupName |
        Select-Object -Property ServerKeyName, Type, Uri, Thumbprint, CreationDate

        $vaultKeys.foreach( { $keys += ([key]::new($_.ServerKeyName, $_.Type, $_.Uri, $_.Thumbprint, $_.CreationDate)) })

        [database[]]$database = @()    
        $tdeInfo = Get-AzSqlDatabase -ServerName $s.Name -ResourceGroupName $s.ResourceGroupName | 
        Get-AzSqlDatabaseTransparentDataEncryption | Select-Object -Property DatabaseName, State

        $tdeInfo.foreach( { $database += ([database]::new($_.DatabaseName, $_.State)) })

        $sub.Servers += ([sqlserver]::new($s.Name, $s.ResourceGroupName, $keys, $database))
    }
    [void]$result.Add($sub)
}

$outFile = Join-Path -Path $PSScriptRoot -ChildPath output.json
$result | ConvertTo-Json -Depth 5 | Tee-Object -FilePath $outFile 
Write-Host "Result copied to $outFile"
