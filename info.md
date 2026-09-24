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