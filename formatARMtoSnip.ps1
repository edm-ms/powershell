$inputFile = Get-Content .\armSample.json


For ($i = 0; $i -lt $inputFile.Length; $i ++) {

    If ($inputFile[$i].Contains('"')) {

        $armElements = $inputFile[$i].Split('"')

        # // Loop through all elements 
        For ($c = 1; $c -lt $armElements.Length; $c ++) {

            if ($armElements[$c].Contains(':')) { 

                if ($armElements[$c].Contains('{')) {
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
        
        $snippetFix = '"' + $armElements
        Write-Host $snippetFix
    }

    Else {
        $snippetFix = '"' + $inputFile[$i] + '",'
        Write-Host $snippetFix
    }

}