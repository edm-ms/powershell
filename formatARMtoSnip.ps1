$inputFile = Get-Content .\armSample.json
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

        # // Loop through all elements and format the specific pieces
        For ($c = 1; $c -lt $armElements.Length; $c ++) {

            if ($armElements[$c].Contains(':')) { 

                if ($armElements[$c].Contains('{') -or $armElements[$c].Contains('[')) {
                    $armElements[$c] = $armElements[$c] + '",'
                }
                else {
                    $armElements[$c] = $armElements[$c]
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
                        $armElements[$c] = '\"' + $armElements[$c] + '\"'
                    }
                }
            }
        }
        $global:newSnippet += '"' + $armElements
    }

    Else {
        $global:newSnippet += '"' + $inputFile[$i] + '",'
    }
}