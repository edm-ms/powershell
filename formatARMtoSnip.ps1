$inputFile = Get-Clipboard 
$global:newSnippet = @()

$global:newSnippet += '"My New Snippet": {'
$global:newSnippet += '"prefix": "myarm-newsnipp",'
$global:newSnippet += '"body": ['

For ($i = 0; $i -lt $inputFile.Length; $i ++) {

    If ($inputFile[$i].Contains('"')) {

        $armElements = $inputFile[$i].Split('"')

        #$armElements[0] = $armElements[0].Trim()
        # // Loop through all elements and format the specific pieces
        For ($c = 1; $c -lt $armElements.Length; $c ++) {

            if ($armElements[$c].Contains(':')) { 

                if ($armElements[$c].Contains('{') -or $armElements[$c].Contains('[') -or $armElements[$c].Contains('true') -or $armElements[$c].Contains('false')) {
                    $armElements[$c] = $armElements[$c] + '",'
                }
                else {
                    # // If this element is a URL do the following formatting
                    if ($armElements[$c].Contains('/')) {
                        $armElements[$c] = '\"' + $armElements[$c] + '\"'
                    }
                    else {
                        # // Add space after colon
                        $armElements[$c] = $armElements[$c].Trim() + ' '    
                    }
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
                        # // If there is a $ indicating schema add an extra $ so it does not get removed
                        if ($armElements[$c].Contains('$')) {
                            $armElements[$c] = '\"$' + $armElements[$c] + '\"'

                        }
                        else {
                            # // Add opening and closing \ with "" to an element that is not a ': , { }'
                            $armElements[$c] = '\"' + $armElements[$c] + '\"'    
                        }
                        
                        
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

$global:newSnippet += '],'
$global:newSnippet += '"description": "Description of thing"'
$global:newSnippet += '},'

$global:newSnippet | clip