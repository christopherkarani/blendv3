#!/usr/bin/env python3
import os

services = [
    'Blendv3/Services/PoolService.swift',
    'Blendv3/Services/BackstopContractService.swift',
    'Blendv3/Services/BlendOracleService.swift',
]

for service_file in services:
    if os.path.exists(service_file):
        with open(service_file, 'r') as f:
            content = f.read()
        
        # Replace response.hash with response.id
        content = content.replace('response.hash', 'response.id')
        
        with open(service_file, 'w') as f:
            f.write(content)
        
        print(f"Updated {service_file}")

print("All services updated!") 