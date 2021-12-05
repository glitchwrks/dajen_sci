Dajen SCI
=========

This repository contains information pertinent to the [Dajen SCI](https://www.glitchwrks.com/2011/11/03/dajen-sci), a S-100 board that provides several handy functions to your average pre IEEE-696 S-100 system, such as an Altair or IMSAI.

monitor16.asm
-------------

This file contains assembly source for the version of the Dajen SCI ROM monitor listed in the manual. It was typed in from the manual, assembled, and the results compared to a dump of [Bill Degnan's Dajen SCI](https://www.vintagecomputer.net/browse_thread.cfm?id=319) ROMs. The typed-in source was then corrected against the ROMs, which caught a few typing errors and ambiguities arising from the somewhat poor quality of the listing in the manual.

This source has been kept as close as possible to the original. Comments indicating page breaks have been inserted. Program labels and comments are as close to the listing as possible, given the quality of the original listing.

An `ORG` statement has been added to the top of the file for the default ROM address of `0xD000`. This file will assemble properly with [our fork of the A85 assembler](https://github.com/glitchwrks/a85/).

dajen.bin
---------

This binary file contains the dump from Bill Degnan's ROMs, modified for 9600 bps console.

mondiff.md
----------

This file describes the differences that were not reconciled between the Dajen source and ROM dumps.

mondiff.diff
------------

Actual diff of the output from assembling the Dajen source and the ROM dump.

dajen2bin.rb
------------

Simple Ruby script to convert the output from the Dajen monitor's `D` command to a binary file. See also `dajen2bin_sample_input.txt`.