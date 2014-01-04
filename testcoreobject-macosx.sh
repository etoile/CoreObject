#!/bin/bash

# This is used in the "Run Script" phase of each of the targets we build,
# if it is set to 1, the resulting binary is run as part of the xcodebuild
export TESTCOREOBJECT_AUTORUN=1 

xcodebuild -project CoreObject.xcodeproj -scheme TestCoreObject
teststatus=$?

xcodebuild -project CoreObject.xcodeproj -scheme BenchmarkCoreObject
benchmarkstatus=$?

xcodebuild -project CoreObject.xcodeproj -scheme BasicPersistence
samplestatus=$?

# printstatus 'message' status
function printstatus {
  if [[ $2 == 0 ]]; then
    echo "(PASS) $1"
  else
    echo "(FAIL) $1"
  fi
}

echo "CoreObject Tests Summary"
echo "========================"
printstatus TestCoreObject $teststatus
printstatus BenchmarkCoreObject $benchmarkstatus
printstatus BasicPersistence $samplestatus

exitstatus=$(( teststatus || benchmarkstatus || samplestatus ))
exit $exitstatus
