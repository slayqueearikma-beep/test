#cloud-config
package_update: true
packages:
  - docker.io
  - docker-compose-plugin
  - git
  - curl

write_files:
  - path: /home/${admin_username}/margem/.keep
    owner: ${admin_username}:${admin_username}
    permissions: "0755"
    content: ""

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ${admin_username}
  - mkdir -p /home/${admin_username}/margem
  - chown -R ${admin_username}:${admin_username} /home/${admin_username}/margem
