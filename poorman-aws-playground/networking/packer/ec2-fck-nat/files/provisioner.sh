#!/bin/bash
echo $SSH_PUBLIC_KEY > /home/ec2-user/.ssh/authorized_keys
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" --output-dir /usr/local/bin
sudo chmod +x /usr/local/bin/kubectl
sudo sed -i '/^PermitRootLogin/ s/.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i '/^PasswordAuthentication/ s/.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i "/^#Port/a Port $SSH_CUSTOM_PORT" /etc/ssh/sshd_config
sudo sed -i "/^#ClientAliveInterval/a ClientAliveInterval 60" /etc/ssh/sshd_config
sudo systemctl enable sshd
sudo echo "mirror.list" > /etc/dnf/vars/mirrorlist
sudo echo ".dualstack" > /etc/dnf/vars/dualstack
sudo dnf clean all
sudo dnf --releasever=latest upgrade -y

sudo dnf install cronie -y
sudo sed -i '$a\@reboot root /root/eks-kubeconfig-update.sh &> /root/eks-kubeconfig-update.logs' /etc/crontab
sudo systemctl enable crond

### Configuring EC2 Hostname ###
if ( [ -f /etc/cloud/cloud.cfg ] ); then {
  grep preserve_hostname /etc/cloud/cloud.cfg 2> /dev/null &> /dev/null
  if ( [ $? -eq 0 ] ); then {
   sudo sed -i "s/.*preserve_hostname.*/preserve_hostname: true/g" /etc/cloud/cloud.cfg
  } else {
   sudo echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
  }
  fi
}
fi

cat << EOF > /tmp/eks-kubeconfig-update.sh
#!/bin/bash

echo "[INFO] - $(date) - Starting script... "
while true; do
    # Run the command and capture the exit code
    aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$REGION"
    EXIT_CODE=\$?

    # Check if the exit code is 0 (success)
    if [ \$EXIT_CODE -eq 0 ]; then
        echo "[INFO] Kubeconfig updated successfully!"
        break  # Exit the loop
    else
        echo "[WARNING] Failed to update kubeconfig. Retrying in 30 seconds..."
        sleep 30
    fi
done

exit 0
EOF

chmod +x /tmp/eks-kubeconfig-update.sh

### If present, removing dot at the end of the hostname ###
ec2_hostname=$(echo $HOSTNAME | sed 's/\.$//')

sudo hostnamectl set-hostname --static $ec2_hostname

