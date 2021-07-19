param (
    [Parameter(Position=1, Mandatory=$true, HelpMessage="Enter full path of CSV file to process: ")]
    [string]$inputFile,

    [Parameter(Position=2, Mandatory=$false, HelpMessage="Enable Hierarchical diagram (works better for large networks)")]
    [switch]$HierarchicalEnabled,

    [Parameter(Position=4, Mandatory=$false, HelpMessage="Enable physics in diagram")]
    [switch]$physics

)

# // Import CSV of peering relationships
$vnets = Import-Csv $inputFile
$TableId = 'RandomId'

# // Find unique vnets
$uniqueVnets = $vnets.SubscriptionID | Select-Object -Unique
$uniqueVnets = $uniqueVnets | Sort-Object

$colors = @('AirForceBlue',
'DarkPink',
'GreenVogue',
'Maroon',
'RedRobin',
'Teak',
'Turbo',
'ViolentViolet',
'WildWatermelon'
)

New-HTML -TitleText 'VNet Diagram' -Online -FilePath VNetPeerings.html {
    New-HTMLSection -HeaderText 'Diagram - Azure Network' -CanCollapse -BackgroundColor White {
        New-HTMLPanel -BackgroundColor White -Invisible {
            New-HTMLDiagram -Height '700px' {
                New-DiagramOptionsPhysics -Enabled $physics -HierarchicalRepulsionAvoidOverlap 1 -HierarchicalRepulsionNodeDistance 200
                New-DiagramEvent -ID $TableId -ColumnID 1
                if ($HierarchicalEnabled) { 
                    #New-DiagramOptionsLayout -RandomSeed 10 -ImprovedLayout $true -ClusterThreshold 5
                    New-DiagramOptionsLayout `
                        -HierarchicalEnabled $HierarchicalEnabled `
                        -HierarchicalNodeSpacing 200 `
                        -HierarchicalLevelSeparation 250 `
                        -HierarchicalTreeSpacing 150 `
                        -HierarchicalSortMethod hubsize `
                        -HierarchicalParentCentralization $true `
                        -HierarchicalDirection FromUpToDown
                }
                New-DiagramOptionsInteraction -Hover $true -Multiselect $true -DragNodes $true -DragView $true
                New-DiagramOptionsLinks -ArrowsToEnabled $false -ArrowsFromEnabled $false -Color BlackPearl
                # // Build nodes
                $i = 0
                $level = 0
                foreach ($vnet in $uniqueVnets) {

                    if ($i -gt $colors.count) { $i = 0 }
                    $level = $level + 1
                    $border = $colors[$i]

                    foreach ($peer in $vnets | Where-Object SubscriptionID -eq $vnet) {
                        
                        $image = 'vnetIcon.png'
                        $label = $peer.VNetName + "`r`n" + $peer.VNetAddressSpace

                        New-DiagramNode `
                            -Id $peer.VNetID `
                            -Label $label `
                            -ImageType circularImage `
                            -Image $image `
                            -ColorBackground White `
                            -ColorHoverBorder Green `
                            -FontBackground White `
                            -ColorBorder $border `
                            -BorderWidth 3 #-Level $level
                        
                    }

                    $i ++
                }

                # // Create links to nodes
                foreach ($vnet in $uniqueVnets) {
                    foreach ($peer in $vnets | Where-Object SubscriptionID -eq $vnet) {
                        
                        $label = $null
                        if ($peer.PeeringState -eq 'Connected') {  $linkColor = 'DarkGreen' }
                        if ($peer.PeeringState -eq 'Disconnected') {  
                            $linkColor = 'Red'
                            $label = "Disconnected" 
                        }
                        if ($peer.PeeringState -eq 'Initializing') {  $linkColor = 'Yellow' }
                        if ($peer.VNetName -like '*transit*' -and $peer.RemoteId -like '*transit*') {
                            $label = "Transit-2-Transit"
                            if ($peer.PeeringState -ne 'Disconnected') { $linkColor = "Black" }
                            if ($peer.PeeringState -eq 'Disconnected') { $label = 'Disconnected-Transit-to-Transit' } 
                            New-DiagramLink -From $peer.VNetID -To $peer.RemoteId `
                                -Color $linkColor `
                                -WidthConstraint 50 `
                                -Dashes `
                                -SmoothType curvedCW `
                                -ArrowsToEnabled `
                                -Label $label `
                                -FontBackground White `
                                -FontAlign middle
            
                          }
                        else {
                            New-DiagramLink -From $peer.VNetID -To $peer.RemoteId -Color $linkColor -WidthConstraint 50 -Label $label -FontBackground White
                        }
                    }
                }
            }
        }
    }

    New-HTMLPanel {
        New-HTMLTable -DataTable $vnets -DataTableID $TableId
    }

} 