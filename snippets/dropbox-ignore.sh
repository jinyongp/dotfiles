abs_path="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"

xattr -w com.dropbox.ignored 1 $abs_path
