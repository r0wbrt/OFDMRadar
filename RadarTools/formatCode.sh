#!/bin/bash
find ./src -name "*.hs" -exec sh -c 'stylish-haskell -i $0' {} \;
find ./test -name "*.hs" -exec sh -c 'stylish-haskell -i $0' {} \;
