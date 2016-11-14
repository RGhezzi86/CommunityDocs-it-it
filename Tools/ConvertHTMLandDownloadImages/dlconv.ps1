#params
param (
[Parameter(Mandatory=$True)][string]$URL, 
[Parameter(Mandatory=$True)][string]$oProject, 
[string]$imageFolder = "img"
)



## uses pandoc to convert an HTML page to an .md file
## then scans the .md file, grabs all links to images, creates an image subfolder,
##  downloads images and places them into the folder while replacing the hyperlink 
##  to the downlaoded version. 
## Then checks if has metadata and tries to create a section with meaningful

#requires -version 3.0

## --- Functions ---

# read the header and store values in variables to be reused in the new header
function ReadMetadata($text) {

# metadata should look like this (at the very top of the .md file)    
# ---
# title: Backup e DataSync con SQL Azure e SQL Server
# description: Backup e DataSync con SQL Azure e SQL Server
# author: MSCommunityPubService
# ms.date: 08/01/2016
# ms.topic: how-to-article
# ms.service: cloud
# ms.custom: CommunityDocs
# ---

	$global:Title = ""
	$global:Description = ""
	$global:Author = ""
	$global:Manager = ""
	$global:MS_Topic = ""
	$global:MS_Service = ""
	$global:MS_Custom = ""
    $global:MS_Author = ""
    $global:MS_Date = ""
    $global:MS_Prod = ""
    $global:MS_Technology = ""

#	isolating header only
	$header = ($text -split "---",3)[1]
	

	if ($header -Match "title: *") {
		$global:Title = (($header -split "title: ", 2)[1] -split "\n")[0].Trim()
	}
	
	if ($header -Match "description: *") {
		$global:Description = (($header -split "description: ", 2)[1]  -split "\n")[0].Trim()
	}
	
	if ($header -Match "ms.service: *") {
		$global:MS_Service = (($header -split "ms.service: ", 2)[1]  -split "\n")[0].Trim()
	}
	# github author handle
	if ($header -Match "author: *") {
		$global:Author = (($header -split "author: ", 2)[1]  -split "\n")[0].Trim()
	}
	
	if ($header -Match "ms.manager: *") {
		$global:Manager = (($header -split "ms.manager: ", 2)[1]  -split "\n")[0].Trim()
	}
	# try manager if ms.manager is not there
    if ($header -Match "manager: *") {
		$global:Manager = (($header -split "manager: ", 2)[1]  -split "\n")[0].Trim()
	}
	
	if ($header -Match "ms.topic: *") {
		$global:MS_Topic = (($header -split "ms.topic: ", 2)[1]  -split "\n")[0].Trim()
	}
    # MS alias for person responsible
    if ($header -Match "ms.author: *") {
		$global:MS_Author = (($header -split "ms.author: ", 2)[1]  -split "\n")[0].Trim()
	}
    
    if ($header -Match "ms.date: *") {
		$global:MS_Date = (($header -split "ms.date: ", 2)[1]  -split "\n")[0].Trim()
	}
    
    if ($header -Match "ms.custom: *") {
		$global:MS_Custom = (($header -split "ms.custom: ", 2)[1]  -split "\n")[0].Trim()
	}
    
    if ($header -Match "ms.prod: *") {
		$global:MS_Prod = (($header -split "ms.prod: ", 2)[1]  -split "\n")[0].Trim()
	}
    if ($header -Match "ms.technology: *") {
		$global:MS_Technology = (($header -split "ms.technology: ", 2)[1]  -split "\n")[0].Trim()
	}
	return $text
}

# -- remove the old properties / tags sections
function RemoveOldHeaders($text) {
    #need to make sure that if there's an article without metadata section

    # splitting in 3 parts - 0 is empty / 1 contains the whole metadata section / 2 the rest of the article except the metadata
	$text = ($text -split "---",3)[2]

	return $text
}

function AddNewHeader($text) {
	$Title = $Title.Replace(":","-")
	$Description = $Description.Replace(":","-")
	
	$NewHeader = "---"+$NEWLINE
	# $NewHeader += "# Sample for CSI"+$NEWLINE
	# $NewHeader += "# required metadata"+$NEWLINE
	$NewHeader += "title: "+$Title+$NEWLINE
	$NewHeader += "description: "+$Description +$NEWLINE
	#$NewHeader += "keywords: "+$Keywords+$NEWLINE
	if (($Author -eq "") -or ($Author -eq "andygonusa") -or ($Author -eq "aldonetti") -or ($Author -eq "walterosR1") -or ($Author -eq "terrysheng")) {
		$NewHeader += "author: MSCommunityPubService"+$NEWLINE
	} else {
		$NewHeader += "author: "+$Author +$NEWLINE
	}
	
    #fixing it for italian
    $NewHeader += "ms.author: walteros"+$NEWLINE
    
    # per Gigel - Manager is not mandatory anymore
    # $NewHeader += "manager: csiism"+$NEWLINE
    
	$NewHeader += "ms.date: "+$MS_Date+$NEWLINE
    
    #forcing it to be a valid topic type
	$NewHeader += "ms.topic: article"+$NEWLINE
    
    #leaving empty for now
	$NewHeader += "ms.prod: "+$NEWLINE
    $NewHeader += "ms.technology: "+$NEWLINE
    
	$NewHeader += "ms.service: "+$MS_Service+$NEWLINE
	#$NewHeader += "ms.assetid: "+$NEWLINE
	#$NewHeader += "# optional metadata"+$NEWLINE
	#$NewHeader += "#ROBOTS: "+$NEWLINE
	#$NewHeader += "#audience:"+$NEWLINE
	#$NewHeader += "#ms.devlang: "+$NEWLINE
	#$NewHeader += "#ms.reviewer: "+$NEWLINE
	#$NewHeader += "#ms.suite: "+$NEWLINE
	#$NewHeader += "#ms.tgt_pltfrm:"+$NEWLINE
	
	
    $NewHeader += "ms.custom: CommunityDocs"+$NEWLINE
	
    $NewHeader += "---"+$NEWLINE+$NEWLINE
	
	$text = $NewHeader + $text.Trim()
	
	return $text
}


## -------------- MAIN ---------------- ##

## vars
$FileText = ""
$NEWLINE = "`r`n"

$Title = ""
$Description = ""
$Author = ""
$MS_Author = ""
$MS_Date = ""
$MS_Manager = ""
$MS_Topic = ""
$MS_Service = ""
$MS_Custom = ""

$imagedir = ""
$oFile = $oProject+".md"

#check if the .md file exists exit with error
if(Test-Path ($oFile)) { 
    echo ("File "+$oFile+" already exists - exiting without action") 
    return
}


# use pandoc to convert HTML page to MD in local file
Invoke-Expression -Command ('pandoc -f html -t markdown -o '+$oFile+' '+$URL)

#if the .md file was generated
if(Test-Path ($oFile))
{
    #create the dir for the images if it does not exist
    $imagedir = (Get-Item -Path ".\" -Verbose).FullName+"\"+$imageFolder+"\"
    if((Test-Path ($imagedir)) -eq $false) 
    {
        mkdir $imagedir;
    }
    
    #create the dir for the project images if it does not exist
    #imagedir shoudl already have a backslash added at the end
    #oProject not, so atting it here
    $imagedir = $imagedir+$oProject+"\"
    if((Test-Path ($imagedir)) -eq $false) 
    {
        mkdir $imagedir;
    }
    
    
    #get the list of images from the web dom
    $wrq = Invoke-WebRequest -Uri $URL -UseBasicParsing
    # only the ones bigger than a certain size to avoid icons and pixels
    #$images = $wrq.Images | Where {($_.Width -gt 50) -or ($_.Height -gt 50)}
    $wrq.Images | % { 
        # I would filter out the images that are not meaningful but
        #  since I will have to touch the file again manually ... I downloads everything
        #  and change every link to a local one
        #if (([int]$_.Width -gt 40) -or ([int]$_.Height -gt 40)) {
            $fImage = ""
            $fImage = $_.src.substring($_.src.lastindexof('/')+1, ($_.src.length - $_.src.lastindexof('/') -1))
            if ($fImage -ne "")
            {
                Invoke-WebRequest $_.src -OutFile ($imagedir+$fImage)
            }
        #}
    }
    
    #the .md file exists, read and look for hyperlinks with images
    Get-Content $oFile -Raw -Encoding UTF8 | % {$FileText += $_ + "NEWLINE"}

    $imageRelPath = $imageFolder+"/"+$oProject+"/"
    $beforeText =""
    $afterText=$FileText
    # while there's an image in the aftertext
    while ($afterText -Match '\!\[') {
            # this works but it splits immediately all of the file, not just the first occurrence        
            #$splitDelimiters = "![","]","(",")"
            #$splittedText = $afterText.Split($splitDelimiters ,[System.StringSplitOptions]::RemoveEmptyEntries)
            #$beforeText = $beforeText+$splittedText[0]
            #$hText =$splittedText[1]
            #$link = $splittedText[2]
            #$aftertext = $splittedText[3]
            
            $beforeText = $beforeText+($afterText -split '\!\[', 2)[0]
            $afterText = ($afterText -split '\!\[', 2)[1]
    		
            $hText =($afterText -split '\](.*)\(', 2)[0]
            $afterText = ($afterText -split '\](.*)\(', 2)[2]
            
    		$link = ($afterText -split '\)', 2)[0]
            $aftertext = ($afterText -split '\)', 2)[1]
            if ($link -ne "") {
                #if it contains the filename among those downlaoded
                    #then replace the URL with the path to the local image
                #otherwise skip it
                
                #I create the new URI to the local image - relative to imgfolder
                $newLink = $imageRelPath + ($link.substring($link.lastindexof('/')+1, ($link.length - $link.lastindexof('/') -1)))
                
                # add the new link to the beforetext
                $beforeText = $beforeText+"!["+$hText+"]("+$newLink+")"
            }
    	
    }
    #join the before and (remaining) after
    $FileText = $beforeText+$afterText
    
    # take care of metadata
    ReadMetadata($FileText)
    if( $Title -ne "" -and $MS_Topic -ne "article" )  {
    	$FileText = RemoveOldHeaders($FileText)
    	$FileText = AddNewHeader($FileText)
    }

    #remove the originally added NEWLINE text
	#$FileText.Replace("NEWLINE","`r`n")  | Out-File $_.FullName -Force -Encoding UTF8
	$FileText = $FileText.Replace("NEWLINE","`r`n")  
	
    # deleting the file on disk prior to writing the new one
    Remove-Item -Path $oFile
    
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
	[System.IO.File]::WriteAllLines((Get-Item -Path ".\" -Verbose).FullName+"\"+$oFile, $FileText, $Utf8NoBomEncoding)   

}
else
{
    echo ('File '+($oFile)+' does not exist.') 
}



#Get-ChildItem -Path C:\logs\ -Filter "*.txt" | % {
#    $text = ""
#    Get-Content $_.FullName | % {$text += $_ + "NEWLINE"}
#    $text = $text -Replace "<Default*DefaultValue>",""
#    $text.Replace("NEWLINE","`r`n") | Out-File $_.FullName -Force
#}

