using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

<# # Input bindings are passed in via param block.
param($Timer)

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
} #>

# Open json file with details on resources to scale up
$json = (Get-Content ".\ScaleUpCosmos\resources.json" -Raw) | ConvertFrom-Json


foreach($item in $json.resources){

    $resourceGroupName = $item.resourceGroupName
    $accountName = $item.accountName
    $api = $item.api #sql, cassandra, gremlin, mongodb, table
    $throughputType = $item.throughputType #manual, autoscale
    $resourceName = $item.resourceName
    $throughputIncr = $item.throughputIncr
    $maxThroughputCutoff =$item.maxThroughputCutoff

    # Store database and container level names in an array. 
    $resourceArray = $resourceName.split("/")

    # When array.count -eq 2, it's dedicated throughput versus shared.
    if($resourceArray.Count -eq 2){
        $isDedicatedThroughput = $true
    }
    else {
        $isDedicatedThroughput = $false
    }

    Write-Host "Updating throughput on resource....."
    Write-Host "ResourceGroup = $resourceGroupName"
    Write-Host "Account = $accountName"
    Write-Host "Api = $api"
    Write-Host "Throughput Type = $throughputType"
    Write-Host "Resource Name = $resourceName"
    Write-Host "ThroughputIncr = $throughputIncr"
    Write-Host "maxThroughputCutoff = $maxThroughputCutoff"

    $currentThroughput = Get-AzCosmosDBSqlContainerThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] | Select-Object -ExpandProperty Throughput
    $Newthroughput = $currentThroughput +  $throughputIncr -as [Int32]

    if ($Newthroughput -gt $maxThroughputCutoff){
        Write-Host "Cannot set throughput to $Newthroughput RU/s, above maximum cutoff throughput $maxThroughputCutoff RU/s configured, exiting script."
        exit
    }
     
    switch($api){
        "sql"{
            if($isDedicatedThroughput){ #container level throughput
                                
                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBSqlContainerThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }
                

                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBSqlContainerThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] -Throughput $Newthroughput

                }
                else {
                    Update-AzCosmosDBSqlContainerThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] -AutoscaleMaxThroughput $Newthroughput
                }
            }
            else{ #database level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }
                
                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -Throughput $Newthroughput
                }
                else {
                    Update-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -AutoscaleMaxThroughput $Newthroughput
                }
            }
        }
        "mongodb"{
            if($isDedicatedThroughput){ #collection level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBMongoDBCollectionThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }

                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBMongoDBCollectionThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] -Throughput $Newthroughput

                }
                else {
                    Update-AzCosmosDBMongoDBCollectionThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] -AutoscaleMaxThroughput $Newthroughput
                }
            }
            else{ #database level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBMongoDBDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }
                
                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBMongoDBDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -Throughput $Newthroughput
                }
                else {
                    Update-AzCosmosDBMongoDBDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -AutoscaleMaxThroughput $Newthroughput
                }
            }
        }
        "cassandra"{
            if($isDedicatedThroughput){ #table level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBCassandraTableThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -KeyspaceName $resourceArray[0] -Name $resourceArray[1] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }

                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBCassandraTableThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -KeyspaceName $resourceArray[0] -Name $resourceArray[1] -Throughput $Newthroughput

                }
                else {
                    Update-AzCosmosDBCassandraTableThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -KeyspaceName $resourceArray[0] -Name $resourceArray[1] -AutoscaleMaxThroughput $Newthroughput
                }
            }
            else{ #keyspace level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBCassandraKeyspaceThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }
                
                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBCassandraKeyspaceThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -Throughput $Newthroughput
                }
                else {
                    Update-AzCosmosDBCassandraKeyspaceThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -AutoscaleMaxThroughput $Newthroughput
                }
            }
        }
        "gremlin"{
            if($isDedicatedThroughput){ #graph level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBGremlinGraphThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }

                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBGremlinGraphThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] -Throughput $Newthroughput

                }
                else {
                    Update-AzCosmosDBGremlinGraphThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -DatabaseName $resourceArray[0] -Name $resourceArray[1] -AutoscaleMaxThroughput $Newthroughput
                }
            }
            else{ #database level throughput

                # Ensure throughput is not set below the Minimum Throughput for the resource.
                $minThroughput = Get-AzCosmosDBGremlinDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] | Select-Object -ExpandProperty MinimumThroughput

                if($minThroughput -gt $Newthroughput)
                {
                    Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                    $Newthroughput = $minThroughput -as [Int32]
                }
                
                # Set the Throughput
                if($throughputType -eq "manual"){
                    Update-AzCosmosDBGremlinDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -Throughput $Newthroughput
                }
                else {
                    Update-AzCosmosDBGremlinDatabaseThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -AutoscaleMaxThroughput $Newthroughput
                }
            }
        }
        "table"{
            #table level throughput

            # Ensure throughput is not set below the Minimum Throughput for the resource.
            $minThroughput = Get-AzCosmosDBTableThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] | Select-Object -ExpandProperty MinimumThroughput

            if($minThroughput -gt $Newthroughput)
            {
                Write-Host "Cannot set throughput to $Newthroughput RU/s, below minimum throughput, setting to minimum allowed throughput, $minThroughput RU/s"
                $Newthroughput = $minThroughput -as [Int32]
            }
            
            # Set the Throughput
            if($throughputType -eq "manual"){
                Update-AzCosmosDBTableThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -Throughput $Newthroughput
            }
            else {
                Update-AzCosmosDBTableThroughput -ResourceGroupName $resourceGroupName -AccountName $accountName -Name $resourceArray[0] -AutoscaleMaxThroughput $Newthroughput
            }
        }
    }

    Write-Host "Throughput scaled up on resource $resourceName in account $accountName using $throughputType from $currentThroughput RU/s to $Newthroughput RU/s`n`n"

}

# Write an information log with the current time.
Write-Host "Cosmos DB ScaleUpTrigger ran! TIME: $currentUTCtime"
$body = "Cosmos DB ScaleUpTrigger ran successfully! TIME: $currentUTCtime"

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})


<# using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

if ($name) {
    $body = "Hello, $name. This HTTP triggered function executed successfully."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
 #>