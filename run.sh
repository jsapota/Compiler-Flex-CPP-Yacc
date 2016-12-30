#!/bin/bash

clear
make clean
make
./compiler.out < $1 > $2
./interpreter.out $2


