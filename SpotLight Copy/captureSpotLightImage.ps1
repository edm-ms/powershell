$imageSource = $env:userprofile + "\AppData\Local\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets\"

# This is the image destination variable, by default we copy to a new folder named LoginScreen in your user profile
# pictures directory.

$imageDestination = $env:userprofile + "\Pictures\LoginScreen\"

# Check to see if new image location exists, if not, create it

If ((Test-Path $imageDestination) -eq $false) { New-Item -ItemType Directory -Path $imageDestination }

# Find all large images in the source directory

$bigImages = Get-ChildItem $imageSource | Where-Object {$_.Length -gt 200000}

# Create ImageFile COM Object

$image  = New-Object -ComObject Wia.ImageFile

# Loop through all imaged in the list matching ones that are 1920 wide and copy them to the destination

ForEach ($imageItem in $bigImages) {
    $image.loadfile($imageItem.FullName)
    if ($image.Width -eq 1920) { 
        $imageName = $imageItem.Name + ".jpg"
        copy-item $imageItem.FullName -Destination ($imageDestination + $imageName)
    }
}