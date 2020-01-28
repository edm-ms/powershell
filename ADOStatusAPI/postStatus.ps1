# // Read the content of a file published to the release pipeline that contains the PR ID number

$PrId = Get-Content $(System.DefaultWorkingDirectory)/_$(app)-$(environment)-build/pr.id/pr.id

# // Assign variable names: $(pat) is an ADO variable with a personal access token

$personalAccessToken="$(pat)"
$organizationName = "My.Org.NAme"
$project = "My.Project.Name"
$repo = "My.Repo.Name"

# // Generate login token

$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)"))
$header = @{Authorization=("Basic {0}" -f $token)}

# // Generate json payload to post

$postBody = @{
    "state"="succeeded";
    "description"="Azure resource deployment was successful.";
    "context"=@{
        "name"="Release Successful"
    }
}

# // Assign status API URL

$projectsUrl = "https://dev.azure.com/$organizationName/$project/_apis/git/repositories/$repo/pullRequests/$PrId/statuses?api-version=5.1-preview.1"

# // Post message to status API endpoint

$postStatus = Invoke-WebRequest -Uri $projectsUrl -Method POST -Headers $header -Body ($postBody | ConvertTo-Json) -ContentType "application/json"

# // Write output to cli for logging

Write-Host $postStatus