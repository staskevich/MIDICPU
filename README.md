MIDI CPU

copyright John Staskevich, 2017

john@codeandcopper.com


This work is licensed under a Creative Commons Attribution 4.0 International License.
http://creativecommons.org/licenses/by/4.0/


HARDWARE:


Eagle 6 board layout files and OpenOffice BOMs are included in the pcb/ folder. There is also a design for a "programming cradle" that mates the test points on the MIDI CPU with a PIC programmer for ICSP.


A public CircuitHub project is available for on-demand manufacturing:
https://circuithub.com/projects/CodeandCopper1/MIDICPU


FIRMWARE:


The code in the src/ folder can be assembled for the PIC16F887 device using Microchip's MPASM assembler. Selected firmware images are located in the hex/ folder. Firmware patches in SysEx format are in the syx/ folder.
