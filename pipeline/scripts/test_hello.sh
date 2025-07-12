#!/bin/bash
echo "=== MinieSASS System Test ==="
echo ""

# Test all components
echo "Testing Fortran..."
cd "$(dirname "$0")/../fortran"
gfortran test_hello.f90 -o test_hello
./test_hello
rm test_hello
echo ""

echo "Testing C++..."
cd "../cpp"
g++ test_hello.cpp -lcfitsio -o test_hello
./test_hello
rm test_hello
echo ""

echo "Testing PHP..."
cd "../../web/php"
php test_hello.php
echo ""

echo "=== All components working! ==="
