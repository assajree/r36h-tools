==========================================================================================================
Project/Product:			RTL8188FTV/RTL8188FU Driver for the R36S & R36H
By:							XNL Future Technologies & kelebek333 (Github)
Project/Product Page:		https://www.teamxnl.com/R36-RTL8188FTV-DRIVER/
Install Tutorial (Blog):	https://www.teamxnl.com/installing-cheap-wifi-on-your-r36s-or-r36h/
Install Tutorial (Video):	https://www.youtube.com/watch?v=3Ka4UdghNhQ
XNL GitHub:					https://github.com/XNLFutureTechnologies/R36-RTL8188FTV-DRIVER
Original Source:			https://github.com/kelebek333/rtl8188fu  
License:					GPL-2.0
  
NOTE:  
YES! The name of this driver might be a bit confusing for those which are paying attention,  
because it actually is the RTL8188FU driver, but this is the driver which is (also) used for the  
RTL8188FTV. The RTL8188FTV is however the chipset you'll encounter 95% of the time when you are trying
to buy a cheap USB WiFi dongle online from sources like Amazon, AliExpress, Ebay etc when you are
buying a RTL8188 USB Dongle (and the sellers often don't mention the FTV part).

Personally I would recommend to get an RTL8188ETV though if possible, I personally have much better,
faster and stable connections using the ETV boards, but those can be quite difficult to find due to
the sellers leaving out the letter part of the chipset.

I did tested this driver quite extensively with all kinds of tests on my R36H development unit,
a clean install on the R36H and a clean install on the R36S, and had no issues at all with this driver
using various cheap as heck ($1.50) USB RTL8188FTV dongles. There was however one dongle which kept
disconnecting, had poor speeds etc, but that was a dongle out of a set of 5 I bought and all others did
worked correctly. So I'm assuming (and are fairly certain) that the dongle itself was just the culprit.
==========================================================================================================

# !Compatability Warning!
This driver is ONLY intended for the R36S and R36H running on ArkOS 12242024 or later.  
It is also important that your ArkOS/Linux uses the 4.4.189 kernel.  
  
To be certain that your device is (well SHOULD BE) compatible with this driver, I HIGHLY  
recommend to first download the XNL Compatability Check and running that tool on your console.  
  
It will check for the correct ArkOS version, kernel, linux version, bootfiles etc.  
And if everything checks out, then you can most likely install this driver without any issues  

You can download the XNL Compatability Check from my website directly or from my GitHub:  
Website: https://www.teamxnl.com/product/r36-xcc/  
GitHub:  https://github.com/XNLFutureTechnologies/XNL_R36_Compatibility_Check    
  
# Introduction:
This driver is intended for the R36S and R36H and it's basically nothing more than an installer  
package I've compiled and created from the original drivers from kelebek333 from this repository:
https://github.com/kelebek333/rtl8188fu  

For most regular users using the R36S or R36H it can be quite overwhelming if you need to installer  
kernel headers, package managers and more of the alike over SSH.  
  
Which can be even a "bigger task" if you can't even connect it to your network because your (USB) WiFi  
card isn't working/recognized by the R36S/R36H ;)  
  
Therefor I decided to do the 'heavy lifting' for those users by creating this installer package.  
This is basically a pre-compiled driver which users can easily install by just placing the folder  
XNL RTL8188FTV in this download on their SD-Card in the folder: /roms/Tools  
  
## Instructions
1. Just copy paste the entire XNL RTL8188FTV folder into the /roms/tools folder so that it becomes:  
/roms/Tools/XNL RTL8188FTV  
  
If you are using the OS-TF card (SD-Card 1, which is RECOMMENDED!) then in Windows it would simply be  
something like (replacing the drive letter E: with the drive letter of your EASYROMS partition of course):  
E:\Tools\XNL RTL8188FTV  
  
2. Then after putting the SD-Card back into your R36S/R36H you'll need to go to either Options or RetroPie  
(this depends on your theme, but for most it will most likely be options, it can however for some themes  
also be system).  
  
3. Then you'll goto -> Tools and then to -> XNL RTL8188FTV and select Install Driver  
  
The XNL RTL8188FTV Driver Installer should do the rest for you.  
  
## No Support or Updates
Please do realize that I myself DO NOT offer ANY support or updates to the driver files itself (the source) 
AT ALL! If the original developer creates an update, then I will update this installer package with the  
new version if needed, and if the ArkOS kernel changes/updates in the future I will also provide an update  
to be compatible with that version if needed. But I will NOT fix possible driver issues, add features or  
ANYTHING like that.  
  
Why not? Simple: While I consider myself quite capable in programming quite a lot of stuff, ranging from  
microcontrollers, game-scripts, applications, games, engines and whatever, programming (messing with)  
Linux Kernel Drivers for PUBLIC RELEASE is not something I feel comfortable enough to do!  
  
Yes, I have written/experimented with drivers, modified drivers etc for Linux which I do use myself,  
but I just don't want to mess with that stuff when it comes to other peoples hardware when they install it,  
simple as that. I quite decently know my way around Linux, but my "Native Language" is Windows, .NET, compact  
framework etc. So sorry, no special/XNL Specific updates, modifications or whatever for these drivers.  
  
==========================================================================================================  
LICENSE NOTE: 
The original license of the original developer of these drivers apply, which is the 
GPL-2.0 License which can be found here:  
https://github.com/kelebek333/rtl8188fu?tab=GPL-2.0-1-ov-file#readme  
==========================================================================================================  
  
  
