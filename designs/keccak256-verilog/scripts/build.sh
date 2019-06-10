#!/bin/sh

# Vivado directory
vivadoDir="/opt/Xilinx/Vivado/2019.1"

# Screen 0 = no - 1 = yes. Set to 1 if you'd like to background the vivado compile in a screen.
# Must have screen installed in the directory path
useScreen=1

# Home directory of the shell files
baseDir="/home/sensel/shell_git"

# Design Name
designName="keccak256-verilog"

# Security Implementation - secure or open
secImpl="secure"

# Board name - bcu1525 or cvp13
boardName="bcu1525"

# Put together build identifier
shortid="2"
hostname=`hostname`
time=`date +%m%d-%H_%M-%N`
buildId="${time}_${hostname}_${shortid}"

# Directives are the following...
# default, runtimeoptimized, AreaOptimized_high, AreaOptimized_medium, AlternateRoutability, AreaMapLargeShiftRegToBRAM
# AreaMultThresholdDSP, FewerCarryChains
# Can also set options like -resource_sharing, -retiming
synthStrat="-directive AlternateRoutability -retiming -resource_sharing off"

# Directives are the following...
# Explore, EarlyBlockPlacement, WLDrivenBlockPlacement, ExtraNetDelay_high, ExtraNetDelay_low, AltSpreadLogic_high
# AltSpreadLogic_medium, AltSpreadLogic_low, ExtraPostPlacementOpt, ExtraTimingOpt, SSI_SpreadLogic_high, SSI_SpreadLogic_low
# SSI_SpreadSLLs, SSI_BalanceSLLs, SSI_BalanceSLRs, RuntimeOptimized, Quick, Default
placeStrat="-directive ExtraNetDelay_high -timing_summary -no_fanout_opt -no_bufg_opt"

# Directives are the following...
# Explore, AggressiveExplore, NoTimingRelaxation, MoreGlobalIterations, HigherDelayCost, AdvancedSkewModeling, AlternateCLBRouting,
# Runtime Optimized, Quick, Default
routeStrat="-directive MoreGlobalIterations -tns_cleanup -ultrathreads -timing_summary"

# Create build directories and copies source code
mkdir -p ${baseDir}/designs/${designName}/builds
mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}
mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/src
mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/scripts
mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/logs
mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/tmp

cp -r ${baseDir}/designs/${designName}/src/* ${baseDir}/designs/${designName}/builds/${buildId}/src/
cp -r ${baseDir}/designs/${designName}/scripts/* ${baseDir}/designs/${designName}/builds/${buildId}/scripts/

# Generate vivado settings file
cat > ${baseDir}/designs/${designName}/builds/${buildId}/scripts/settings.tcl <<EOF
set buildId "${buildId}"
set boardName "${boardName}"
set designName "${designName}"

set secImpl "${secImpl}"

set baseDir "${baseDir}"

set synthStrat "${synthStrat}"
set placeStrat "${placeStrat}"
set routeStrat "${routeStrat}"
EOF

# Generate usable build launch script
echo "#!/bin/sh
source $vivadoDir/settings64.sh
$vivadoDir/bin/vivado -mode batch -source ${baseDir}/designs/${designName}/builds/${buildId}/scripts/build.tcl -journal ${baseDir}/designs/${designName}/builds/${buildId}/logs/vivado.jou -log ${baseDir}/designs/${designName}/builds/${buildId}/logs/vivado.log -tempDir ${baseDir}/designs/${designName}/builds/${buildId}/tmp/ -tclargs ${baseDir}/designs/${designName}/builds/${buildId}
"> ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh

chmod +rx ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh

# Launch the build process
if [[ "${useScreen}" = "1" ]];
then
  screen -dmS ${buildId} ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh
else
  $buildId ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh
fi  
