param(
[String]$ServerListVariableName = "",
[String]$workspaceID = "5ba541f4-9db7-45f6-b9cd-5175be96348c",
[String]$AutomationAccount = "Automate-3742010c-b092-4f45-9448-d0ba8d14c7b8-EUS",
[String]$Resourcegroup = "DefaultResourceGroup-EUS"
)

try {
Write-Output "Starting query on $workspaceID $AutomationAccount $Resourcegroup $ServerListVariableName  "
$AzureContext = (Connect-AzAccount -Identity).context
$query = "Heartbeat| where TimeGenerated >ago(15min) | where  Solutions  has ""Updates""| distinct Computer"
$queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceID -Query $query #-DefaultProfile $AzureContext
$queryresultsArray = [System.Linq.Enumerable]::ToArray($queryResults.Results)

Write-Output "QueryResults: $($queryresultsArray |out-string)"

$Serverlist=@()

If (![string]::IsNullOrEmpty($ServerListVariableName)){ 
$AzAutomationVariable = Get-AzAutomationVariable  -ResourceGroupName $Resourcegroup -AutomationAccountName $AutomationAccount -Name $ServerListVariableName
$Serverlist = $AzAutomationVariable.Value.split("`n")
}

else {  
$Serverlist = Get-AzVM -status | Where-Object {$_.PowerState -eq "VM running" -and $_.StorageProfile.OsDisk.OsType -eq "Windows"} | Select-Object Name
}
$missedservers =@()

Write-Output "Target Azure vms: $($Serverlist |out-string)"

foreach ($server in $Serverlist) {
  Write-Output "processing $server"
  if (!($queryresultsArray -imatch $server)) {
  $missedservers += $Server
  Write-Output "This VM $Server is not enable Update management yet!"
  }
}

if ($missedservers.count -gt 0) {
Write-Error   "The list of VMs miss update management: $($missedservers|Out-String)"
throw "The list of VMs missed update management: $($missedservers|Out-String)"
}
else {
Write-Output "All Target VMs have Update management enabled."
}
}
catch{
throw "$($_.Exception)"
}