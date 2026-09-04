# build.ps1 — Build & run Kavacha under Icarus Verilog 12+ on Windows.
#   .\build.ps1            # build + smoke
#   .\build.ps1 cosim      # build + smoke + golden co-simulation
#   .\build.ps1 rvfi       # RVFI (riscv-formal interface) self-check
#   .\build.ps1 debug      # JTAG / Debug-Module self-check
#   .\build.ps1 pmp        # SECURE config: U-mode + PMP test
#   .\build.ps1 epmp       # SECURE config: ePMP rules test
#   .\build.ps1 ecc        # register-file SECDED ECC unit test
#   .\build.ps1 axil       # AXI4-Lite master/slave interconnect self-check
#   .\build.ps1 fpga       # FPGA SoC simulation (UART banner + LED blink)
#   .\build.ps1 clean
param([string]$Action = "sim")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$IVL = if ($env:IVERILOG) { $env:IVERILOG } else { "C:\iverilog\bin\iverilog.exe" }
$VVP = if ($env:VVP)      { $env:VVP }      else { "C:\iverilog\bin\vvp.exe" }

$C = "rtl\common"
$R = "rtl"
$cells = @(
  "$C\kavacha_pkg.sv","$C\kavacha_alu.sv","$C\kavacha_regfile.sv",
  "$C\kavacha_muldiv.sv","$C\kavacha_csr.sv","$C\kavacha_rvc.sv",
  "$C\kavacha_immgen.sv","$C\kavacha_branch.sv","$C\kavacha_decode.sv","$C\kavacha_pmp.sv"
)
$core = @("$R\kavacha_core.sv","$R\kavacha_debug.sv","$R\kavacha_soc.sv")

if ($Action -eq "clean") {
    Remove-Item -Recurse -Force sim, programs\build -ErrorAction SilentlyContinue
    Get-ChildItem -Filter *.vcd -ErrorAction SilentlyContinue | Remove-Item
    Write-Host "Cleaned."; return
}
New-Item -ItemType Directory -Force sim, programs\build | Out-Null

if ($Action -eq "ecc") {
    Write-Host "Building register-file SECDED ECC unit test..."
    & $IVL -g2012 -I $C -o sim\tb_regfile_ecc "$C\kavacha_pkg.sv" "$C\kavacha_regfile_ecc.sv" tb\tb_regfile_ecc.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_regfile_ecc; return
}

if ($Action -eq "pmp" -or $Action -eq "epmp") {
    $hexName = if ($Action -eq "epmp") { "epmp" } else { "pmp" }
    Write-Host "Building Kavacha SECURE sim (U-mode + PMP + ePMP + regfile ECC)..."
    & $IVL -g2012 -DKAVACHA_SECURE -I $C -I $R -o sim\tb_kavacha @cells "$C\kavacha_regfile_ecc.sv" @core tb\tb_kavacha.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    Write-Host "Running $Action test on Kavacha..."
    & $VVP sim\tb_kavacha "+IMEM=programs\build\$hexName.hex"; return
}

if ($Action -eq "axil") {
    python programs\build_smoke.py
    if ($LASTEXITCODE -ne 0) { throw "build_smoke.py failed" }
    Write-Host "Building AXI4-Lite bus integration self-check..."
    & $IVL -g2012 -I $C -I $R -o sim\tb_kavacha_axil @cells "$R\kavacha_core.sv" "$R\kavacha_debug.sv" "$R\kavacha_axil.sv" tb\tb_kavacha_axil.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_kavacha_axil +IMEM=programs\build\smoke.hex; return
}

python programs\build_smoke.py
if ($LASTEXITCODE -ne 0) { throw "build_smoke.py failed" }

Write-Host "Compiling..."
& $IVL -g2012 -I $C -I $R -o sim\tb_kavacha @cells @core tb\tb_kavacha.sv
if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }

Write-Host "Running smoke..."
& $VVP sim\tb_kavacha +IMEM=programs\build\smoke.hex

if ($Action -eq "cosim") {
    Write-Host "Co-simulating against the golden RV32IM ISA model..."
    $env:VVP = $VVP
    python tools\cosim.py --hex programs\build\smoke.hex --sim sim\tb_kavacha
}
if ($Action -eq "rvfi") {
    Write-Host "Building RVFI self-check..."
    & $IVL -g2012 -DRISCV_FORMAL -I $C -I $R -o sim\tb_kavacha_rvfi @cells @core tb\tb_kavacha_rvfi.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_kavacha_rvfi +IMEM=programs\build\smoke.hex
}
if ($Action -eq "debug") {
    Write-Host "Building JTAG / Debug-Module self-check..."
    & $IVL -g2012 -I $C -I $R -o sim\tb_kavacha_debug @cells @core tb\tb_kavacha_debug.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_kavacha_debug +IMEM=programs\build\smoke.hex
}
if ($Action -eq "fpga") {
    Write-Host "Building FPGA SoC sim (UART banner + LED blink)..."
    & $IVL -g2012 -DSIMULATION -I $C -I $R -o sim\tb_kavacha_fpga `
        @cells "$R\kavacha_core.sv" "$R\kavacha_debug.sv" `
        fpga\common\kavacha_uart.sv fpga\kavacha_fpga.sv fpga\tb_kavacha_fpga.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_kavacha_fpga
}
