#!/bin/bash -ex

dnf update -y
dnf install -y nginx
# Get metadata token first
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Get instance information using the token
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Instance Information</title>
    <style>
        body {
            font-family: Tahoma, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 0;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            padding: 40px;
            text-align: center;
            max-width: 500px;
            width: 90%;
        }
        h1 {
            color: #333;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
        }
        .label {
            font-weight: bold;
            color: #555;
            display: inline-block;
            width: 120px;
        }
        .value {
            color: #333;
            font-family: monospace;
            background: #e9ecef;
            padding: 2px 6px;
            border-radius: 3px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ Instance Info</h1>
        <div class="info-box">
            <div><span class="label">Private IP:</span> <span class="value">$PRIVATE_IP</span></div>
        </div>
        <div class="info-box">
            <div><span class="label">Instance ID:</span> <span class="value">$INSTANCE_ID</span></div>
        </div>
    </div>
</body>
</html>
EOF

systemctl daemon-reload
systemctl enable --now --no-block nginx.service
systemctl start nginx.service