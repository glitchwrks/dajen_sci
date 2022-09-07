Assembly vs. ROM Dump Differences
---------------------------------

There are two differences that were not accounted for in diff'ing the assembler output and ROM dump:

* Starting at `0xD3FA` and ending at `0xD3FF`, six bytes are different:

```
    -000003f0  d2 b7 f2 ec d3 cd 3e d2  db d2 00 30 00 11 00 00  |......>....0....|
    +000003f0  d2 b7 f2 ec d3 cd 3e d2  db d2 b7 f2 ec d3 3e 80  |......>.......>.|
```

These bytes appear to modify `CASR0` cassette read routine. The first line is the dump from ROM, and appears to `NOP` out three bytes (`0x30` being a nonstandard opcode for `NOP`), and then load `DE` with `0x0000`. Not sure what the purpose of this is, if any. Unlikely to be bitrot, but perhaps when I modified the ROMs for 9600 bps console, something happened to that block of memory.

* Starting at `0xD7B7` and ending at `0xD7BC`, six bytes are different:

```
    -000007b0  be cd d4 d0 f5 d4 f0 e8  03 35 05 0d 00 45 53 43  |.........5...ESC|
    +000007b0  be cd d4 d0 f5 d4 f0 59  02 20 03 70 04 45 53 43  |.......Y. .p.ESC|
```

The bytes at `0xD7BB` and `0xD7BC` are the bitrate constants for the serial port, which I changed from the default 110 bps to 9600 bps apparently before dumping ROMs. So, that leaves four bytes.

The bytes from `0xD7B7` to `0xD7BA` control cassette read/write speeds. The values in the ROM dump match up with the 1500 bps Tarbell standard. Presumably the original owner of Bill Degnan's Dajen SCI modified these bytes so that the SCI's cassette interface was Tarbell compatible.

Perhaps that explains what was going on with the first set of differences mentioned above -- perhaps it's something to improve Tarbell compatibility?