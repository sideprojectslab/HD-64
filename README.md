# HD-64

If you would like to get in touch with the developer, please join the SPL [Discord](https://discord.gg/gJsCgebkDw) server.

[FULL README (PDF)](https://raw.githubusercontent.com/sideprojectslab/HD-64/main/doc/README.pdf)

HD-64 is an RF-modulator replacement for the Commodore-64 computer which features a Full-HD 50/60Hz Micro-HDMI video+audio output. Crucially, the HD-64 is not a replacement for the VIC-II, which still needs to be mounted on the motherboard

Instead of digitizing the VIC's analog video output signal, the HD-64 "sniffs" the C64's memory bus and recreates a pixel-perfect video output by means of emulation implemented on FPGA. The reconstructed video is then upscaled to Full-HD resolution, merged with the digitized audio from the SID, and sent out as HDMI.

<figure align="center" id="HD-64">
	<img src="doc/pictures/hd64_solo.png" width="70%">
	<figcaption>HD-64 Main Board</figcaption>
</figure>

<figure align="center" id="hd64_shortboard_back">
	<img src="doc/pictures/hd64_shortboard_back.png" width="100%">
	<figcaption>HD-64 Short-Board Assembly</figcaption>
</figure>

<figure align="center" id="hd64_longboard">
	<img src="doc/pictures/hd64_longboard.png" width="70%">
	<figcaption>HD-64 Long-Board Assembly</figcaption>
</figure>

# 1. License
License information is included on top of all software source files as well as in all schematics. Files that do not contain explicit licensing information are subject to the licensing terms stated in the LICENSE.txt provided in the main project folder:

Unless stated otherwise in individual files, all hardware design Schematics, Bill of Materials, Gerber files and manuals are licensed under Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/

Unless otherwise stated in individual files, all software source files are Licensed under the Apache License, Version 2.0. You may obtain a copy of this license at http://www.apache.org/licenses/LICENSE-2.0

# 2. Disclaimer
All material is provided on an 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND in accordance to the license deed applicable to each individual file.

# 3. Contributing
Work in Progress...
