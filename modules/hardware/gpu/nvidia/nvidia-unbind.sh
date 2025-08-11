sudo systemctl stop nvidia-persistenced
sudo systemctl stop lactd
systemctl --user stop sunshine

echo "0000:0e:00.0" >/sys/class/drm/card1/device/driver/unbind
