# icesugar-riscv

[FPGACode-ide](https://github.com/MuratovAS/FPGACode-ide) -> [**IceSugar-riscv**](https://github.com/MuratovAS/icesugar-riscv) -> *IceSugar-tv80.....*

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
make test       #add-on for testing individual fragments
```
