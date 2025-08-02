# JSE
JSE (Job Specific Equipement) is an addon for FFXI that tracks the AF, RELIC, EMPY gear you have and the next available upgrades. 
It looks for the NQ, +1, +2, +3, +4 versions that you have for a specific job and tells you which upgrade materials you already have / need to augment the JSE to the next stage.


## Commands

**`//jse [ af | relic | empy ] <JOB>`**
- Check equipement and available upgrades for a specific job, displays upgrade materials you already have / need to augment the pecific job equipements

**`//jsetrack [ af | relic | empy ] <JOB>`** 
- same as the basic //jse command but also displays in an extra dragable window 

**`//jsetrack [ hide | show ] `**
- to hide/show the extra //jsetrack window  

**`//jseall af <JOB>`** 
- Specifically for AF Cards, this will check for the gear on the current logged in character and check for cards on all charcters/mules that have an existing data file. ( you need to load the addon at least once on the mule for it to create a data file)

**`//jsecurrency`**
- Displays tracked currencies for upgrades and their values ( Rem's Chapters, Gallimauffry, Apollyon and Temenos Units )

**`//jsehelp`**
- Displays the available commands

## Examples ##

**/jse af WHM**  -  displays needed materials to upgrade WHM Artifact armor
![jse_af_WHM](https://i.imgur.com/wyjHUQk.jpeg)

**//jse relic BST**  -  displays needed materials to upgrade BST Relic armor
![jse_relic_BST](https://i.imgur.com/zMMdS1P.jpeg)

**//jse af RDM**  -  displays needed materials to upgrade RDM Artifact armor
![jse_af_RDM](https://i.imgur.com/EOfzfUW.jpeg)

**//jseall af PUP**  -  check for P. Cards on all your mules 
![jseall_af_PUP](https://i.imgur.com/YQGXnXD.jpeg)

**//jsetrack af WHM**  -  displays results in a dragable window
![jsetrack_af_WHM](https://i.imgur.com/P5p3x90.jpeg)

**//jsecurrency**  -  displays relevent currencies
![jsecurrency](https://i.imgur.com/fYggKX1.jpeg)

**//jsehelp**  -  displays all commands
![jsehelp](https://i.imgur.com/pXHzTlf.jpeg)

### v1.10
* Added a new command //jsetrack that displays the results in a dragable window. 
* Merged the //jse and //jsemats into a single command.
* Typo fix for SCH gear names and Maliya. Coral Orb.

### v1.01
* Minor display updates and syntax fix for DRG gear.

### v1.00
* First release.
