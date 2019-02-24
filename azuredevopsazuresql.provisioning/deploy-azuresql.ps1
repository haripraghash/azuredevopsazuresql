Param (
	# Resource group
	[Parameter(Mandatory=$true)]
	[string] $ResourceGroupLocation,

    [string] $ResourceGroupName = 'acme-product-eun-dev-data-resgrp',

    [string] $TemplateFile = 'azuredeploy.json',

	# General
	[Parameter(Mandatory=$true)]
	[string] $Environment = 'dev',

	# App service plan
	[string] $AppServicePlanSKUTier = 'Standard',

	[string] $AppServicePlanSKUName = 'S1',

	# product db
	[string] $SqlDbEdition = 'Standard',

	[string] $SqlDbTier = 'S1',
	
	[Parameter(Mandatory=$true)]
	[string] $keyVaultResourceGroup
)

$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

$AadTenantId = (Get-AzureRmContext).Tenant.Id
$ArtifactsStorageAccountName = $ResourceNamePrefix + $Environment + 'artifacts'
$ArtifactsStorageContainerName = 'artifacts'
$ArtifactsStagingDirectory = '.'

function Generate-Password ($length = 20, $nonAlphaChars = 5)
{
	Add-Type -AssemblyName System.Web
	
	[char[]] $illegalChars = @(':', '/', '\', '@', '''', '"', ';', '.', '+', '#')

	do {
		$hasIllegalChars = $false
		$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)

		$illegalChars | ForEach-Object {
			if ($password -like "*$_*") {
				$hasIllegalChars = $true
			}
		}
	} while ($hasIllegalChars)
	ConvertTo-SecureString $password -AsPlainText -Force
}

function CreateResourceGroup() {
	$parameters = New-Object -TypeName Hashtable

	# general
	$parameters['environment'] = $Environment

	# product sql db	
	$parameters['sqlDbEdition'] = $SqlDbEdition
	$parameters['sqlDbTier'] = $SqlDbTier

	$parameters['sqlServerAdminLogin'] = $SqlServerAdminLogin
	$parameters['sqlServerAdminLoginPassword'] = $SqlServerAdminLoginPassword

	.\Deploy-AzureResourcegroup.ps1 `
	    -resourcegrouplocation $ResourceGroupLocation `
		-resourcegroupname $ResourceGroupName `
		-uploadartifacts `
		-storageaccountname $ArtifactsStorageAccountName `
		-storagecontainername $ArtifactsStorageContainerName `
		-artifactstagingdirectory $ArtifactsStagingDirectory `
		-templatefile $TemplateFile `
		-templateparameters $parameters
}

function Main() {
	$deployment = CreateResourceGroup
	$deployment

	if ($deployment.ProvisioningState -eq 'Failed'){
		throw "Deployment was unsuccessful"
	}
	
	
	$keyVaultName = $deployment.outputs.keyVaultName.Value

	# SQL server
	$SqlServerName = $deployment.outputs.sqlServerName.Value
	$SqlServerDbName = $deployment.outputs.sqlDbName.Value
    $SqlServiceConnectionString = $deployment.outputs.connectionString.Value
	$BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlServerAdminLoginPassword)
	$sqlServerAdminLoginPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)

	
	Write-Host "##vso[task.setvariable variable=SqlServerName;]$SqlServerName"
	Write-Host "##vso[task.setvariable variable=SqlServerDbName;]$SqlServerDbName"
	Write-Host "##vso[task.setvariable variable=SqlServerAppAdminLogin;]$sqlServerAdminLogin"
	Write-Host "##vso[task.setvariable variable=SqlServerAppAdminLoginPassword;issecret=true;]$sqlServerAdminLoginPasswordPlain"
	Write-Host "##vso[task.setvariable variable=SqlServerConnectionStringWithPassword;]$SqlServiceConnectionString"

	Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroup
  Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'sql-server-connection-string' `
  -SecretValue $SqlServiceConnectionString
  Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'sql-server-username' `
  -SecretValue (ConvertTo-SecureString $SqlServerAdminLogin -AsPlainText -Force) 
  Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name '"sql-server-password' `
  -SecretValue $sqlServerAdminLoginPassword
}


$SqlServerAdminLogin = "productadmin"
$SqlServerAdminLoginPassword = Generate-Password
Main