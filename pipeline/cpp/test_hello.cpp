#include <iostream>
#include <fitsio.h>

int main() {
    std::cout << "Hello from C++!" << std::endl;
    
    float version;
    fits_get_version(&version);
    std::cout << "CFITSIO version: " << version << std::endl;
    
    std::cout << "FITS handling ready." << std::endl;
    return 0;
}
