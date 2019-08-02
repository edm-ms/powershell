#param (
#    [Parameter(Position=1, Mandatory=$true, HelpMessage="Specify ARM JSON file to inport.")]
#    [string]$inputFile

#    )

#try {

#    if ($inputFile -eq $null) {

#        throw 'Empty or missing input file!'
        
#    }

#    $inputFile = Get-Content $inputFile

#}
#catch {

#    Write-Error $_

#}

$inputFile = Get-Content .\snippetSample.json
$global:newSnippet = @()

# // Header data:
#"Name of thing": {
#    "prefix": "arm-resource",
#    "body": [

# // Footer data:
#],
#"description": "Description of thing"
#},

For ($i = 0; $i -lt $inputFile.Length; $i ++) {

    If ($inputFile[$i].Contains('"')) {

        $armElements = $inputFile[$i].Split('"')

        #$armElements[0] = $armElements[0].Trim()
        # // Loop through all elements and format the specific pieces
        For ($c = 1; $c -lt $armElements.Length; $c ++) {

            if ($armElements[$c].Contains(':')) { 

                if ($armElements[$c].Contains('{') -or $armElements[$c].Contains('[')) {
                    $armElements[$c] = $armElements[$c] + '",'
                }
                else {

                    # // Add space after colon
                    $armElements[$c] = $armElements[$c] + ' '
                }
            }
            else {

                If ($armElements[$c].Trim() -eq ',') {
                    $armElements[$c] = $armElements[$c] + '",'
                }
                else {
                    if ($armElements[$c].Trim() -eq '') {
                        $armElements[$c] = $armElements[$c] + '",'
                    }
                    else {
                        # // Add opening and closing \ with "" to an element that is not a ': , { }'
                        $armElements[$c] = '\"' + $armElements[$c] + '\"'
                    }
                }
            }
        }
        $armElements = $armElements -join ''
        $global:newSnippet += '"' + $armElements
    }

    Else {
        $global:newSnippet += '"' + $inputFile[$i] + '",'
    }
}

$global:newSnippet | clip