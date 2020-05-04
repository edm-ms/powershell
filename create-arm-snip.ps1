# Get clipboard contents
$inputFile = Get-Clipboard

# Set global variable 
$global:newSnippet = @()

# Add starter
$global:newSnippet += '"ARMSnippet": {'
$global:newSnippet += '"prefix": "arm-newsnipp",'
$global:newSnippet += '"body": ['

# Loop through clipboard contents
For ($i = 0; $i -lt $inputFile.Length; $i ++) {

    # If a line with a " is found start parsing"
    If ($inputFile[$i].Contains('"')) {

        # Split line into parts with a " delimiter
        $inputLine = $inputFile[$i].Split('"')

        # Loop through all elements in the " split and escape the "
        for ($part = 1; $part -lt $inputLine.Count; $part ++) {
            $inputLine[$part] = '\"' + $inputLine[$part]
        }

        # Remove whitespace
        $inputLine = $inputLine -join ''

        # If string contains a $ add an extra
        if ($inputLine.IndexOf('$') -ge 0) { 
            $inputLine = $inputLine.Insert($inputLine.IndexOf('$'), '$')
        }
        
        # Add new line to global variable
        $global:newSnippet += '"' + $inputLine + '",'
    }

    else {
        # If there was no " add one at the begin and end of the line
        $global:newSnippet += '"'+ $inputFile[$i] + '",'    
    }

}

# Add snippet closing
$global:newSnippet += '],'
$global:newSnippet += '"description": "Description of thing"'
$global:newSnippet += '},'

# Copy snippet to clipboard
$global:newSnippet | clip