[Variables]
bgWidth=600
bgHeight=300
cornerRoundness=3
; Colors
colorBg=15,15,15
colorDialArc=150,150,150
colorMoon=200,200,200
colorMoonBg=30,30,30
colorMoonBorder=70,70,70
colorSun=250,222,110
; Font settings
fontFace=IBM Plex Sans
fontFaceCn=IBM Plex Sans Condensed
fontSizeDefault=11
colorTextDefault=230,230,230
; Dial settings
dialRadius=250
dialStartX=3
dialArcThickness=6
dialObjectRadius=23
; Moon settings
moonBorderThickness=4
moonInnerRadius=(#dialObjectRadius# - #moonBorderThickness#)
moonArcStartX=(#dialStartX# - #dialObjectRadius#)
moonArcStartY=(#dialRadius# - #moonBorderThickness#)

[StyleString]
FontFace=#fontFace#
FontColor=#colorTextDefault#
FontSize=#fontSizeDefault#
Antialias=1