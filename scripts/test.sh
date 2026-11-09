#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/checks
swiftc -swift-version 6 -parse-as-library Sources/QuotaMonitor/Models/*.swift Sources/QuotaMonitor/DataSources/*.swift Sources/QuotaMonitor/State/*.swift Sources/QuotaMonitor/Persistence/*.swift Tests/QuotaMonitorTests/QuotaTests.swift -o .build/checks/QuotaTests
.build/checks/QuotaTests
