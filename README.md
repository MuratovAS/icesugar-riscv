# icesugar-riscv

[FPGACode-ide](https://github.com/MuratovAS/FPGACode-ide) -> [**IceSugar-riscv**](https://github.com/MuratovAS/icesugar-riscv) -> [IceSugar-tv80](https://github.com/MuratovAS/icesugar-z80) -> [IceSugar-6502](https://github.com/MuratovAS/icesugar-6502)

Here you will find a project for IceSugar implementing RISCV32.
As well as full automation of assembly and testing.
More detailed documentation on usage in the [FPGACode-ide](https://github.com/MuratovAS/FPGACode-ide).

This project is based on the developments of [picorv32](https://github.com/YosysHQ/picorv32)

## Usage

The commands can be executed manually in the terminal as well as through the `Task menu` in `Code`

```bash
make all        #Project assembly
make synthesis  #Synthesis RTL
make flash      #Flash ROM
make prog       #Flash SRAM
make sim        #Perform Testbench
make formatter  #Perform code formatting
make build_fw   #Build firmware
make flash_fw   #Build firmware
make clean      #Cleaning the assembly of the project
make toolchain  #Install assembly tools
```

## Using IceSugar resources
```
Info: Device utilisation:
Info:            ICESTORM_LC:  5273/ 5280    99%
Info:           ICESTORM_RAM:     4/   30    13%
Info:                  SB_IO:    16/   96    16%
Info:                  SB_GB:     8/    8   100%
Info:           ICESTORM_PLL:     0/    1     0%
Info:            SB_WARMBOOT:     0/    1     0%
Info:           ICESTORM_DSP:     0/    8     0%
Info:         ICESTORM_HFOSC:     0/    1     0%
Info:         ICESTORM_LFOSC:     0/    1     0%
Info:                 SB_I2C:     0/    2     0%
Info:                 SB_SPI:     0/    2     0%
Info:                 IO_I3C:     0/    2     0%
Info:            SB_LEDDA_IP:     0/    1     0%
Info:            SB_RGBA_DRV:     0/    1     0%
Info:         ICESTORM_SPRAM:     4/    4   100%
```
