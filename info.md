```bash
cd ~/Downloads/linuxCheat/MAJOR/storage-monitor

chmod +x install.sh bin/*.sh dist/get.sh
sudo ./install.sh

storage-monitor
growth-tracker snapshot
generate-report
open /opt/storage-monitor/reports/storage-report_*.html

mkdir -p ~/mig-test-src && echo "hello" > ~/mig-test-src/file1.txt
migration-verify before ~/mig-test-src demo
cp -r ~/mig-test-src ~/mig-test-dst
migration-verify after ~/mig-test-dst demo

open docs/index.html
open docs/dashboard.html
open docs/product.html
````



````bash
tar -xzf ~/Downloads/storage-monitor.tar.gz
cd ~/Downloads/linuxCheat/MAJOR/storage-monitor
ls bin/

chmod +x install.sh bin/*.sh dist/get.sh
sudo ./install.sh

growth-tracker snapshot
sudo /opt/storage-monitor/bin/export-dashboard-data.sh
cp /opt/storage-monitor/reports/dashboard-data.json ~/Downloads/linuxCheat/MAJOR/storage-monitor/docs/

cd ~/Downloads/linuxCheat/MAJOR/storage-monitor/docs
python3 -m http.server 8000

#http://localhost:8000/dashboard.html
````
