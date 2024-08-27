#!/bin/bash
gcc -fmodules -flto=full -Wall -Wextra -Wpedantic -std=c11 -O3 -o screenshotwatcher screenshotwatcher.c
