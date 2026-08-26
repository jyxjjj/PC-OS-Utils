#!/bin/bash

swiftc \
    -O \
    -gnone \
    -whole-module-optimization \
    -Xlinker -dead_strip \
    DeviceBattery.swift \
    -o DeviceBattery || exit $?

strip -S -x -T DeviceBattery
