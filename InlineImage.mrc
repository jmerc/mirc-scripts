menu @imageHotlink {
  Preview:downloadImage
}

; Start script if we move the mouse over an image link
on $^*:HOTLINK:/^(?:((http|https)\x3A\x2F{2}\S+)|(www\.\S+\.\S+))\.(png|gif|jpg|jpeg)$/i:#:{
  var %url = $1  
  hadd -m ImagePreview Url %url

  if ($hotlink(event) == rclick) {
    hotlink -md @imageHotlink
  }
  elseif ($hotlink(event) == sclick) {
    ; If a double click comes in, this timer will be cancelled
    .timerDoubleClickDelay -m 1 250 downloadImage
  }

  return
}

; Allow a link to be double clicked to open it in a web browser
on $*:HOTLINK:/^(?:((http|https)\x3A\x2F{2}\S+)|(www\.\S+\.\S+))\.(png|gif|jpg|jpeg)$/i:*:{
  .timerDoubleClickDelay off
  url $1
}

alias -l downloadImage {
  var %url = $hget(ImagePreview,Url)
  if (%url == $null) {
    echo -s URL not saved, aborting
    return
  }
  ; Determine File Extension
  if ($regex(UrlFileExt,%url,/^.*\.(png|gif|jpg|jpeg)$/i) == 0) {
    echo -sg Unable to download image: Image Type not found in URL: %url
    return
  }

  var %fileExt = $regml(UrlFileExt,1)
  var %urlId = $urlget(%url,gf,output. $+ %fileExt,showImage)
  hadd ImagePreview UrlId %urlId
  ; Show Loading Window
  var %windowLeft = $mouse.cx - 30
  var %windowTop = $mouse.cy - 30
  var %windowWidth = 200
  var %windowHeight = 100
  var %margin = 5  
  window -padoBfvw0 +d @Image %windowLeft %windowTop %windowWidth %windowHeight
  clear @Image
  drawtext @Image 0 0 $color(text) Loading Image...
  drawrect -r @Image 255 2 %margin $calc(%windowHeight / 2 + %margin) $calc(%windowWidth - 2 * %margin) $calc(%windowHeight / 2 - 2 * %margin)

  .timerImageProgress -m 0 33 updateProgressBar %urlId %windowWidth %windowHeight %margin
}

alias -l updateProgressBar {
  var %urlId = $1
  var %windowWidth = $2
  var %windowHeight = $3
  var %margin = $4

  if ($urlget(%urlId).state != download) return

  var %rcvd = $urlget(%urlId).rcvd
  var %size = $urlget(%urlId).size
  if (%size == 0) {
    echo -sg UpdateProgressBar: RCVD %rcvd Size UNKNOWN
    return
  }

  ; Calculate fill width
  var %percentComplete = $calc(%rcvd / %size)
  drawrect -rf @Image 255 2 %margin $calc(%windowHeight / 2 + %margin) $calc(%percentComplete * (%windowWidth - 2 * %margin)) $calc(%windowHeight / 2 - 2 * %margin)
}

alias -l showImage {
  var %id = $1
  var %state = $urlget(%id).state  
  var %target = $urlget(%id).target
  var %url = $urlget(%id).url

  ; Grab image position from loading window before we close it
  var %imageTop = $window(@Image).cy
  var %imageLeft = $window(@Image).cx

  .timerImageProgress off  
  clear @Image
  window -c @Image

  if (%state != ok) {
    echo -sg Download failed: %state
    echo -sgi8 Reason: $urlget(%id).reply
    return
  }

  if ($pic(%target).size == 0) {
    echo -sg Unable to render target
    return
  }

  var %imageWidth = $pic(%target).width
  var %imageHeight = $pic(%target).height

  ; Max of 640 width or 480 height
  var %widthRatio = $calc(640 / %imageWidth)
  var %heightRatio = $calc(480 / %imageHeight)
  if (%widthRatio < 1 || %heightRatio < 1) {
    %imageWidth = $calc($iif(%widthRatio < %heightRatio,%widthRatio,%heightRatio) * %imageWidth)  
    %imageHeight = $calc($iif(%widthRatio < %heightRatio,%widthRatio,%heightRatio) * %imageHeight)  
  }

  ; Open Window
  window -padoBfvw0 +d @Image %imageLeft %imageTop %imageWidth %imageHeight

  ; Draw image
  drawpic -s @Image 0 0 %imageWidth %imageHeight " $+ %target $+ "

  ; More than 1 frame?  let's play it!
  var %gifFrames = $pic(%target).frames
  if (%gifFrames > 1) {
    ; Store parameters for Gif drawing
    hadd ImagePreview GifTarget %target
    hadd ImagePreview GifFrame 1
    hadd ImagePreview GifFrames %gifFrames
    hadd ImagePreview ImageWidth %imageWidth
    hadd ImagePreview ImageHeight %imageHeight

    .timerPlayGif -h 0 $pick(%target).delay drawGifFrame
  }
}

alias -l drawGifFrame {
  var %target = $hget(ImagePreview,GifTarget)
  var %gifFrame = $hget(ImagePreview,GifFrame)
  var %gifFrames = $hget(ImagePreview,GifFrames)
  var %imageWidth = $hget(ImagePreview,ImageWidth)
  var %imageHeight = $hget(ImagePreview,ImageHeight)

  drawpic -sco @Image 0 0 %imageWidth %imageHeight %gifFrame " $+ %target $+ "

  inc %gifFrame
  if (%gifFrame >= %gifFrames || %gifFrame > 100) {
    set %gifFrame 0
  }
  hadd ImagePreview GifFrame %gifFrame
}

menu @Image {
  sclick:closeImage
  ;leave:closeImage
}

alias -l closeImage {
  ; Stop any download if it's in progress
  .timerImageProgress off
  var %urlId = $hget(ImagePreview,UrlId)
  if (%urlId != $null) %urlId = $urlget(%urlId,c)
  .timerPlayGif off
  window -c @Image
  hfree ImagePreview
}
