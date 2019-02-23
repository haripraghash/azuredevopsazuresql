#
# localdeploy.ps1
# script can be used for deployment from local pc to Azure
clear
#Clear-AzureRmContext -Scope Process

if ((Get-AzureRmContext).Subscription.Name -ne "Visual Studio Enterprise")
{
    Login-AzureRmAccount

    Set-AzureRmContext -Subscription Visual Studio Enterprise
}

$AadAdmin = "..."
$AadPassword = ConvertTo-SecureString "..." -AsPlainText -Force
$ResourceGroupLocation = "northeurope"
$Environment = "dev"

.\deploy-productapi.ps1 -AadAdmin $AadAdmin `
   -AadPassword $AadPassword `
   -ResourceGroupLocation $ResourceGroupLocation `
   -environment $Environment