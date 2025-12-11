#!/bin/bash -ex

yum -y groupinstall "Development Tools"
yum -y install cmake3
yum -y install tc || true
yum -y install iproute-tc || true
cd /root
curl https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.gz | tar xz
ln -s /root/boost_1_89_0 /home/ec2-user/boost
git clone https://github.com/aws-samples/aws-gateway-load-balancer-tunnel-handler.git
cd aws-gateway-load-balancer-tunnel-handler
cmake3 .
make
echo "[Unit]" > /usr/lib/systemd/system/gwlbtun.service
echo "Description=AWS GWLB Tunnel Handler" >> /usr/lib/systemd/system/gwlbtun.service
echo "" >> /usr/lib/systemd/system/gwlbtun.service
echo "[Service]" >> /usr/lib/systemd/system/gwlbtun.service
echo "ExecStart=/root/aws-gateway-load-balancer-tunnel-handler/gwlbtun -c /root/aws-gateway-load-balancer-tunnel-handler/example-scripts/create-passthrough.sh -p 80" >> /usr/lib/systemd/system/gwlbtun.service
echo "Restart=always" >> /usr/lib/systemd/system/gwlbtun.service
echo "RestartSec=5s" >> /usr/lib/systemd/system/gwlbtun.service
systemctl daemon-reload
systemctl enable --now --no-block gwlbtun.service
systemctl start gwlbtun.service
