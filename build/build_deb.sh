# Organize artifacts
echo -n "Organizing artifacts..."
mkdir -p "deb/usr/share/vls"
cp "../vls" "deb/usr/share/vls/vls"

mkdir -p "deb/usr/share/doc/vls"
cp "../LICENSE" "deb/usr/share/doc/vls/copyright"
echo  >> "deb/usr/share/doc/vls/copyright"
cat "../THIRD_PARTY_LICENSES.md" >> "deb/usr/share/doc/vls/copyright"
echo " done."

# Update version information
VLS_VERSION=$(cat ../src/VERSION)
echo -n "Updating version information..."
sed -i "s/Version:.*$/Version: $VLS_VERSION/g" "deb/DEBIAN/control"
echo " done."

# Create .deb
dpkg-deb -b deb/ vls-$VLS_VERSION-$1.deb
