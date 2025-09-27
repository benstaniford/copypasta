#!/bin/bash
set -e

# Build script for creating Debian package

# Clean any previous builds
rm -rf build/ dist/ *.egg-info/ debian/.debhelper/ debian/copyp/ debian/tmp/

# Create source distribution
python3 setup.py sdist

# Build the Debian package
dpkg-buildpackage -us -uc -b

echo "Debian package built successfully!"
echo "Package location: ../copyp_1.0.0-1_all.deb"