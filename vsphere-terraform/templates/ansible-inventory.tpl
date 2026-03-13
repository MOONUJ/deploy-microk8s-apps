[microk8s]
%{ for i, ip in vm_ips ~}
${vm_names[i]} ansible_host=${ip} ansible_user=${vm_user} ansible_ssh_private_key_file=${ssh_private_key_file}
%{ endfor ~}

[microk8s:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
