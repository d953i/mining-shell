#!/bin/bash

# Vivado directory
vivadoDir="/opt/Xilinx/Vivado/2018.3"

# Screen 0 = no - 1 = yes. Set to 1 if you'd like to background the vivado compile in a screen.
# Must have screen installed in the directory path
useScreen=1

# Home directory of the shell files
baseDir="/home/sensel/shell"

# Design Name
designName="keccak256-verilog"

# core dcp file location
# Set this to the path of the fully synth'd core you wish to churn placement on
coreDCP="${baseDir}/designs/${designName}/builds/0507-16_38-csyn-fchains/${designName}_syn.dcp"

# Security Implementation - secure or open
secImpl="secure"

# Board name - bcu1525 or cvp13
boardName="bcu1525"

# Put together build identifier
shortid="r25-l30"
hostname=`hostname`
time=`date +%m%d-%H_%M`
buildIdBase="${time}-cimpl"

# Directives are the following...
# Explore, EarlyBlockPlacement, WLDrivenBlockPlacement, ExtraNetDelay_high, ExtraNetDelay_low, AltSpreadLogic_high
# AltSpreadLogic_medium, AltSpreadLogic_low, ExtraPostPlacementOpt, ExtraTimingOpt, SSI_SpreadLogic_high, SSI_SpreadLogic_low
# SSI_SpreadSLLs, SSI_BalanceSLLs, SSI_BalanceSLRs, SSI_HighUtilSLRs, RuntimeOptimized, Quick, Default
# Define multiple directives to iterate through them
declare -A placeStrats
placeStrats['wldp']="-directive WLDrivenBlockPlacement"
placeStrats['asllow']="-directive AltSpreadLogic_low"
placeStrats['etopt']="-directive ExtraTimingOpt"
placeStrats['slrutil']="-directive SSI_HighUtilSLRs"


if [ ! -f ${coreDCP} ]; then
  echo "Core DCP file not found."
  echo "Exiting..."
  exit
fi

echo "Launching simultaneous synthesis for the following options"
for K in "${!placeStrats[@]}"; do
  buildId="${buildIdBase}-${K}"

  echo "Build ID: ${buildId} -- Key: $K -- Directive: ${placeStrats[$K]}" 

  ### Create build directories and copies source code
  mkdir -p ${baseDir}/designs/${designName}/builds
  mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}
  mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/src
  mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/scripts
  mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/logs
  mkdir -p ${baseDir}/designs/${designName}/builds/${buildId}/tmp

  cp -r ${baseDir}/designs/${designName}/src/* ${baseDir}/designs/${designName}/builds/${buildId}/src/
  cp -r ${baseDir}/designs/${designName}/scripts/* ${baseDir}/designs/${designName}/builds/${buildId}/scripts/

  ### Generate vivado settings file
cat > ${baseDir}/designs/${designName}/builds/${buildId}/scripts/settings.tcl <<EOF
set buildId "${buildId}"
set boardName "${boardName}"
set designName "${designName}"

set secImpl "${secImpl}"

set baseDir "${baseDir}"

set placeStrat "${placeStrats[$K]}"

set coreDCP "${coreDCP}"
EOF

# Generate usable build launch script
echo "#!/bin/sh
source $vivadoDir/settings64.sh
$vivadoDir/bin/vivado -mode batch -source ${baseDir}/designs/${designName}/builds/${buildId}/scripts/gen_impl.tcl -journal ${baseDir}/designs/${designName}/builds/${buildId}/logs/vivado.jou -log ${baseDir}/designs/${designName}/builds/${buildId}/logs/vivado.log -tempDir ${baseDir}/designs/${designName}/builds/${buildId}/tmp/ -tclargs ${baseDir}/designs/${designName}/builds/${buildId}
"> ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh

  chmod +rx ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh

  ### Launch the build process
  if [[ "${useScreen}" = "1" ]];
  then
    screen -dmS ${buildId} ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh
  else
    $buildId ${baseDir}/designs/${designName}/builds/${buildId}/scripts/launch.sh
  fi  

done


