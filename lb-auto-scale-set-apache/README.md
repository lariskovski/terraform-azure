# Terraform Provisioning

## What Is Created

- create lb
    
    - create lb rule for port 80

- create backend pool

- create scale set

    - VM nic inside backend pool with private ip + primary public ip for ssh access

- output lb public ip

## To Add

- auto scaling

- cloud init --custom data script to install apache

- create nat rule instead of public ip for vm scale set