#!/bin/sh
convertPath=`which convert`
echo ${convertPath}
if [[ ! -f ${convertPath} || -z ${convertPath} ]]; then
echo "warning: Skipping Icon versioning, you need to install ImageMagick and ghostscript (fonts) first, you can use brew to simplify process:
brew install imagemagick
brew install ghostscript"
exit -1;
fi


version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${CONFIGURATION_BUILD_DIR}/${INFOPLIST_PATH}"`
build_num=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${CONFIGURATION_BUILD_DIR}/${INFOPLIST_PATH}"`



shopt -s extglob
build_num="${build_num##*( )}"
shopt -u extglob


function processIcon() {
    base_file=$1
    temp_path=$2
    dest_path=$3
    environment_str=$4
    
    caption="${version}($build_num) \n ${environment_str}"
    echo $caption
    
    if [[ ! -e $base_file ]]; then
    echo "error: file does not exist: ${base_file}"
    exit -1;
    fi
    
    if [[ -z $temp_path ]]; then
    echo "error: temp_path does not exist: ${temp_path}"
    exit -1;
    fi
    
    if [[ -z $dest_path ]]; then
    echo "error: dest_path does not exist: ${dest_path}"
    exit -1;
    fi
    
    file_name=$(basename "$base_file")
    final_file_path="${dest_path}/${file_name}"
    
    base_tmp_normalizedFileName="${file_name%.*}-normalized.${file_name##*.}"
    base_tmp_normalizedFilePath="${temp_path}/${base_tmp_normalizedFileName}"
    
    # Normalize
    echo "Reverting optimized PNG to normal"
    echo "xcrun -sdk iphoneos pngcrush -revert-iphone-optimizations -q '${base_file}' '${base_tmp_normalizedFilePath}'"
    xcrun -sdk iphoneos pngcrush -revert-iphone-optimizations -q "${base_file}" "${base_tmp_normalizedFilePath}"
    
    width=`identify -format %w "${base_tmp_normalizedFilePath}"`
    height=`identify -format %h "${base_tmp_normalizedFilePath}"`
    
    band_height=$((($height * 50) / 100))
    band_position=$(($height - $band_height))
    text_position=$(($band_position - 8))
    point_size=$(((12 * $width) / 100))
    
    echo "Image dimensions ($width x $height) - band height $band_height @ $band_position - point size $point_size"
    
    #
    # blur band and text
    #
    convert "${base_tmp_normalizedFilePath}" -blur 10x8 /tmp/blurred.png
    convert /tmp/blurred.png -gamma 0 -fill white -draw "rectangle 0,$band_position,$width,$height" /tmp/mask.png
    convert -size ${width}x${band_height} xc:none -fill 'rgba(0,0,0,0.2)' -draw "rectangle 0,0,$width,$band_height" /tmp/labels-base.png
    convert -background none -size ${width}x${band_height} -pointsize $point_size -fill white -gravity center -gravity South caption:"$caption" /tmp/labels.png
    
    convert "${base_tmp_normalizedFilePath}" /tmp/blurred.png /tmp/mask.png -composite /tmp/temp.png
    
    rm /tmp/blurred.png
    rm /tmp/mask.png
    
    #
    # compose final image
    #
    filename=New"${base_file}"
    convert /tmp/temp.png /tmp/labels-base.png -geometry +0+$band_position -composite /tmp/labels.png -geometry +0+$text_position -geometry +${w}-${h} -composite -alpha remove "${final_file_path}"
    
    # clean up
    rm /tmp/temp.png
    rm /tmp/labels-base.png
    rm /tmp/labels.png
    rm "${base_tmp_normalizedFilePath}"
    
    echo "Overlayed ${final_file_path}"
}

# 修改为项目中的appIcon正确地址
# icons_dir="${SRCROOT}/Images.xcassets/AppIcon.appiconset"
icons_path="${PROJECT_DIR}/KADOnlinePharmacies/Images.xcassets/AppIcon.appiconset"
icons_tst_path="${PROJECT_DIR}/KADOnlinePharmacies/Images.xcassets/AppIcon-tst.appiconset"
icons_rc_path="${PROJECT_DIR}/KADOnlinePharmacies/Images.xcassets/AppIcon-rc.appiconset"
icons_set=`basename "${icons_path}"`
tmp_path="${TEMP_DIR}/IconVersioning"
rc_str="DEV"
tst_str="TST"
#icons_dest_path="${icons_tst_path}"

echo "icons_path: ${icons_path}"

mkdir -p "${tmp_path}"

# 判断地址是否正确
if [[ $icons_tst_path == "\\" ]]; then
echo "error: destination file path can't be the root directory"
exit -1;
fi

if [[ $icons_rc_path == "\\" ]]; then
echo "error: destination file path can't be the root directory"
exit -1;
fi

rm -rf "${icons_tst_path}"
cp -rf "${icons_path}" "${icons_tst_path}"

rm -rf "${icons_rc_path}"
cp -rf "${icons_path}" "${icons_rc_path}"

# 
find "${icons_path}" -type f -name "*.png" -print0 |
while IFS= read -r -d '' file; do
echo "$file"
processIcon "${file}" "${tmp_path}" "${icons_tst_path}" "${tst_str}"
processIcon "${file}" "${tmp_path}" "${icons_rc_path}" "${rc_str}"
done