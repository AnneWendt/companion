#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib/

if [ -z "$1" ]; then
    WIDTH=$(cat ~/vidformat.param | xargs | cut -f1 -d" ")
    HEIGHT=$(cat ~/vidformat.param | xargs | cut -f2 -d" ")
    FRAMERATE=$(cat ~/vidformat.param | xargs | cut -f3 -d" ")
else
    WIDTH=$1
    HEIGHT=$2
    FRAMERATE=$3
fi

echo "starting video with width $WIDTH height $HEIGHT framerate $FRAMERATE"

# load Pi camera v4l2 driver
if ! lsmod | grep -q bcm2835_v4l2; then
    echo "loading bcm2835 v4l2 module"
    sudo modprobe bcm2835-v4l2
fi

# load gstreamer options for both cameras
gstOptions=$(tr '\n' ' ' < $HOME/gstreamer2.param)
echo "gst options: $gstOptions"
gstOptionsExtra=$(tr '\n' ' ' < $HOME/gstreamer2-extra.param)
echo "gst options extra: $gstOptionsExtra"

# number of successfully streaming cameras
num_cams=0

# start them all
for dev_path in $(ls /dev/video*); do
    echo "Attempting to start camera on $dev_path"
    # try to start cameras for just one frame. this will fail if they are not capable of H264.
    # make sure framesize and framerate are supported. posting into fakesink instead of actual connection.
    gst-launch-1.0 -v v4l2src device=$dev_path do-timestamp=true num-buffers=1 ! video/x-h264, width=$WIDTH, height=$HEIGHT, framerate=$FRAMERATE/1 ! h264parse ! queue ! rtph264pay config-interval=10 pt=96 ! fakesink
    if [ $? == 0 ]; then
        echo "Number of cameras: $num_cams"
        if [ $num_cams == 1 ]; then
            echo "Starting second camera"
            screen -dm -S video_2 bash -c "export LD_LIBRARY_PATH=/usr/local/lib/ && gst-launch-1.0 -v v4l2src device=$dev_path  do-timestamp=true ! video/x-h264, width=$WIDTH, height=$HEIGHT, framerate=$FRAMERATE/1 $gstOptionsExtra"
            break
        elif [ $num_cams == 0 ]; then
            echo "Starting first camera"
            screen -dm -S video_1 bash -c "export LD_LIBRARY_PATH=/usr/local/lib/ && gst-launch-1.0 -v v4l2src device=$dev_path  do-timestamp=true ! video/x-h264, width=$WIDTH, height=$HEIGHT, framerate=$FRAMERATE/1 $gstOptions"
            num_cams=1
        fi
        echo "Number of cameras now: $num_cams"
    else
        echo "Camera on $dev_path could not be started"
    fi
done

