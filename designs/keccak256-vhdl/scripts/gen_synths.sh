#!/bin/bash

# Vivado directory
vivadoDir="/opt/Xilinx/Vivado/2018.3"

# Screen 0 = no - 1 = yes. Set to 1 if you'd like to background the vivado compile in a screen.
# Must have screen installed in the directory path
useScreen=1

# Home directory of the shell files
baseDir="/home/sensel/shell"

# Design Name
designName="keccak256-vhdl"

# Security Implementation - secure or open
secImpl="secure"

# Board name - bcu1525 or cvp13
boardName="bcu1525"

# Put together build identifier
shortid="r25-l30"
hostname=`hostname`
time=`date +%m%d-%H_%M`
buildIdBase="${time}-csyn"

# Directives are the following...
# default, runtimeoptimized, AreaOptimized_high, AreaOptimized_medium, AlternateRoutability, AreaMapLargeShiftRegToBRAM
# AreaMultThresholdDSP, FewerCarryChains
# Can also set options like -resource_sharing, -retiming

# Define multiple directives to iterate through them
declare -A synthStrats
synthStrats['aohigh']="-directive AreaOptimized_high -retiming -resource_sharing off"
synthStrats['aomed']="-directive AreaOptimized_medium -retiming -resource_sharing off"
synthStrats['altrt']="-directive AlternateRoutability -retiming -resource_sharing off"
synthStrats['fchains']="-directive FewerCarryChains -retiming -resource_sharing off"

echo "Launching simultaneous synthesis for the following options"

for K in "${!synthStrats[@]}"; do
  buildId="${buildIdBase}-${K}"
  echo "Build ID: ${buildId} -- Key: $K -- Directive: ${synthStrats[$K]}" 

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

set synthStrat "${synthStrats[$K]}"
EOF

# Generate usable build launch script
echo "#!/bin/sh
source $vivadoDir/settings64.sh
$vivadoDir/bin/vivado -mode batch -source ${baseDir}/designs/${designName}/builds/${buildId}/scripts/gen_synths.tcl -journal ${baseDir}/designs/${designName}/builds/${buildId}/logs/vivado.jou -log ${baseDir}/designs/${designName}/builds/${buildId}/logs/vivado.log -tempDir ${baseDir}/designs/${designName}/builds/${buildId}/tmp/ -tclargs ${baseDir}/designs/${designName}/builds/${buildId}
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


