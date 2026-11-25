param([string]$ClientDirectory = "upstream")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-GoldFont([int]$size, [bool]$bold = $true) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    return [System.Drawing.Font]::new('Georgia', [float]$size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}
function Solid([int]$r, [int]$g, [int]$b, [int]$a = 255) {
    return [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($a,$r,$g,$b))
}
function Draw-CenteredText($g, [string]$value, [float]$y, [float]$size, [int]$width, [bool]$outline = $true) {
    $font = New-GoldFont ([int]$size)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $rect = [System.Drawing.RectangleF]::new(0.0,[float]$y,[float]$width,[float]($size*1.5))
    if ($outline) {
        $shade = Solid 14 5 5 230
        for ($dx=-2; $dx -le 2; $dx+=2) {
          for ($dy=-2; $dy -le 2; $dy+=2) {
            $g.DrawString($value,$font,$shade,[System.Drawing.RectangleF]::new([float]$dx,[float]($y+$dy),[float]$width,[float]($size*1.5)),$format)
          }
        }
        $shade.Dispose()
    }
    $gold = Solid 247 208 121
    $g.DrawString($value,$font,$gold,$rect,$format)
    $gold.Dispose(); $font.Dispose(); $format.Dispose()
}
function New-Graphics([System.Drawing.Bitmap]$bmp) {
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    return $g
}
function Make-Splash([string]$path) {
    $w=1280; $h=720
    $bmp=[System.Drawing.Bitmap]::new($w,$h,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g=New-Graphics $bmp
    try {
        $b=[System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new($w,$h),
            [System.Drawing.Color]::FromArgb(19,19,32),[System.Drawing.Color]::FromArgb(5,3,10))
        $g.FillRectangle($b,0,0,$w,$h);$b.Dispose()
        $rng=[System.Random]::new(7351)
        for($i=0;$i -lt 210;$i++){
            $x=$rng.Next(0,$w);$y=$rng.Next(0,500)
            $alpha=$rng.Next(16,85)
            $brush=Solid 218 146 76 $alpha
            $r=$rng.Next(1,4)
            $g.FillEllipse($brush,$x,$y,$r,$r);$brush.Dispose()
        }
        # Distant citadel silhouettes, stone columns and firelight
        $black=Solid 9 10 17
        $g.FillRectangle($black,0,548,$w,172)
        foreach($x in @(68,180,975,1088)){
            $g.FillRectangle($black,$x,215,102,410)
            $g.FillPolygon($black,[System.Drawing.Point[]]@(
               [System.Drawing.Point]::new(($x-20),216),
               [System.Drawing.Point]::new(($x+52),120),
               [System.Drawing.Point]::new(($x+125),216)))
        }
        $black.Dispose()
        $br=Solid 105 35 25 220
        $g.FillRectangle($br,185,288,75,235)
        $g.FillRectangle($br,1020,288,75,235)
        $br.Dispose()
        $p=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(163,151,89,48),7)
        $g.DrawArc($p,420,255,440,440,180,180)
        $g.DrawEllipse($p,528,305,225,225);$p.Dispose()
        $portal=Solid 10 76 92 145;$g.FillEllipse($portal,545,318,191,197);$portal.Dispose()
        $fire=Solid 228 79 19 185
        $g.FillEllipse($fire,125,510,105,105);$g.FillEllipse($fire,1050,510,105,105)
        $fire.Dispose()
        # Centered signature and decorative frame
        $line=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(225,170,78),3)
        $g.DrawLine($line,350,178,930,178); $g.DrawLine($line,365,445,915,445)
        $g.DrawLine($line,490,566,790,566);$line.Dispose()
        Draw-CenteredText $g 'MU' 100 105 $w
        Draw-CenteredText $g 'KABRA' 212 120 $w
        Draw-CenteredText $g 'ONLINE' 369 56 $w
        Draw-CenteredText $g 'SEASON 6  •  EPISODE 3' 471 23 $w $false
        Draw-CenteredText $g 'UN MUNDO, UNA LEYENDA' 592 19 $w $false
        $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Jpeg)
    } finally {$g.Dispose(); $bmp.Dispose()}
}
function Make-Icon([string]$path,[int]$size,[bool]$transparent = $false,[bool]$backgroundOnly = $false) {
    $bmp=[System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=New-Graphics $bmp
    try{
        if(!$transparent){
            $fill=[System.Drawing.Drawing2D.LinearGradientBrush]::new([System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new($size,$size),
            [System.Drawing.Color]::FromArgb(91,9,16),[System.Drawing.Color]::FromArgb(9,9,19))
            $g.FillRectangle($fill,0,0,$size,$size);$fill.Dispose()
        }
        if(!$backgroundOnly){
            $pen=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(245,184,70),[float]([Math]::Max(1,$size*.025)))
            $g.DrawEllipse($pen,$size*.13,$size*.12,$size*.74,$size*.74);$pen.Dispose()
            $f=New-GoldFont ([Math]::Max(15,[int]($size*.44)))
            $format=[System.Drawing.StringFormat]::new();$format.Alignment=[System.Drawing.StringAlignment]::Center
            $shadow=Solid 14 4 5
            $g.DrawString('K',$f,$shadow,[System.Drawing.RectangleF]::new(2,[float]($size*.25+2),[float]($size-4),[float]($size*.55)),$format)
            $gold=Solid 250 195 84
            $g.DrawString('K',$f,$gold,[System.Drawing.RectangleF]::new(0,[float]($size*.25),[float]$size,[float]($size*.55)),$format)
            $f.Dispose();$shadow.Dispose();$gold.Dispose();$format.Dispose()
        }
        $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
    }finally{$g.Dispose();$bmp.Dispose()}
}

$root=Join-Path $ClientDirectory 'MuAndroid/Resources'
$scene=Join-Path $ClientDirectory 'Client.Main/MGContent/Background.jpg'
Make-Splash $scene
$levels=@{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}
foreach($name in $levels.Keys){
  $dir=Join-Path $root "mipmap-$name"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  Make-Icon (Join-Path $dir 'ic_launcher.png') $levels[$name]
  $fg=[int]($levels[$name]*2.25)
  Make-Icon (Join-Path $dir 'ic_launcher_foreground.png') $fg $true
  Make-Icon (Join-Path $dir 'ic_launcher_background.png') $fg $false $true
}
Write-Host "MU KABRA: imagen de inicio y recursos de icono Android generados."
